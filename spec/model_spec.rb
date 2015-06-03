require "spec_helper"

require "active_record"

ActiveRecord::Base.logger = Logger.new(STDOUT)

class Book < ActiveRecord::Base
end

class User < ActiveRecord::Base
  use_shard :user
  has_many :articles
end

class Article < ActiveRecord::Base
  use_shard :user
  belongs_to :user
  has_many :comments
end

class Comment < ActiveRecord::Base
  use_shard :user
  shard_key_object :article
  belongs_to :article
  belongs_to :user
end

base = { adapter: 'sqlite3' }
ActiveRecord::Base.configurations = {
  # 'main_readonly' => base.merge(database: 'main_readonly.sqlite3'),
  # 'main_writable' => base.merge(database: 'main_writable.sqlite3'),
  # 'main2_readonly' => base.merge(database: 'main2_readonly.sqlite3'),
  # 'main2_writable' => base.merge(database: 'main2_writable.sqlite3'),
  # 'main_readonly_special' => base.merge(database: 'main_readonly_special.sqlite3'),
  # 'user' => base.merge(database: 'user.sqlite3'),
  # 'comment_readonly' => base.merge(database: 'comment_readonly.sqlite3'),
  # 'comment_writable' => base.merge(database: 'comment_writable.sqlite3'),
  'default' => base.merge(database: 'default.sqlite3'),
  'user_shard_1_test' => base.merge(database: 'user_shard_1.sqlite3'),
  'user_shard_2_test' => base.merge(database: 'user_shard_2.sqlite3'),
  'user_shard_3_test' => base.merge(database: 'user_shard_3.sqlite3'),
  'user_user_sequence_test' => base.merge(database: 'user_user_sequence.sqlite3'),
  'user_article_sequence_test' => base.merge(database: 'user_article_sequence.sqlite3'),
  'user_comment_sequence_test' => base.merge(database: 'user_comment_sequence.sqlite3')
}
ActiveRecord::Base.establish_connection(:default)

[Book, User, ActiveRecord::Base].each do |model|
  if model.connected?
    raise "ActiveRecord::Base didn't establish connection lazily!"
  end
end
ActiveRecord::Base.connection # Create connection


# [Book].each do |model|
#   if model.connected?
#     raise "#{model.name} didn't establish connection lazily!"
#   end
# end

RSpec.configure do |config|
  if config.files_to_run.one?
    config.full_backtrace = true
    config.default_formatter = 'doc'
  end

   config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    [:user_user_sequence_test, :user_article_sequence_test, :user_comment_sequence_test].each do |db_conn_name|
      [:user_user_sequence, :user_article_sequence, :user_comment_sequence].each do |sequence|
        ActiveRecord::Base.establish_connection(db_conn_name).connection.execute("CREATE TABLE #{sequence.to_s} (id integer primary key autoincrement)")
        ActiveRecord::Base.establish_connection(db_conn_name).connection.execute("INSERT INTO #{sequence.to_s} (id) VALUES (0)")
      end
    end

    ActiveRecord::Base.establish_connection(:user_shard_1_test).connection.execute('CREATE TABLE users (id integer primary key autoincrement, name string)')
    ActiveRecord::Base.establish_connection(:user_shard_2_test).connection.execute('CREATE TABLE users (id integer primary key autoincrement, name string)')
    ActiveRecord::Base.establish_connection(:user_shard_3_test).connection.execute('CREATE TABLE users (id integer primary key autoincrement, name string)')

    ActiveRecord::Base.establish_connection(:user_shard_1_test).connection.execute('CREATE TABLE articles (id integer primary key autoincrement, user_id integer, title string, body string)')
    ActiveRecord::Base.establish_connection(:user_shard_2_test).connection.execute('CREATE TABLE articles (id integer primary key autoincrement, user_id integer, title string, body string)')
    ActiveRecord::Base.establish_connection(:user_shard_3_test).connection.execute('CREATE TABLE articles (id integer primary key autoincrement, user_id integer, title string, body string)')

    comments_table_query = "CREATE TABLE comments (id integer primary key autoincrement, user_id integer, article_id integer, comment string)"
    ActiveRecord::Base.establish_connection(:user_shard_1_test).connection.execute comments_table_query
    ActiveRecord::Base.establish_connection(:user_shard_2_test).connection.execute comments_table_query
    ActiveRecord::Base.establish_connection(:user_shard_3_test).connection.execute comments_table_query

    ActiveRecord::Base.establish_connection(:default)
    Book.connection.execute('CREATE TABLE books (id integer primary key autoincrement)')
    # User.connection.execute('CREATE TABLE users (id integer primary key autoincrement)')
  end

  config.after(:suite) do
    ActiveRecord::Base.configurations.each_value do |config|
      FileUtils.rm_f(config[:database])
    end
  end
end

RSpec.describe ActiveRecordSharding::Model do
  it "default connection" do
    expect(Book).to connect_to('default.sqlite3')
  end

  context "User sharding" do
    it "shard_1, shard_2, shard_3" do
      alice = User.create(name: "alice")
      expect(alice.class).to connect_to('user_shard_2.sqlite3')

      alice_profile = Article.new(title: "Alice profile", body: "Alice profile text")
      alice.articles << alice_profile
      expect(alice_profile.class).to connect_to('user_shard_2.sqlite3')
      expect(alice.articles.count).to eq 1

      bob_profile = Article.create(title: "Bob profile", body: "Bob profile text", user_id: 2)

      expect(alice_profile.id).not_to eq bob_profile.id
      expect(alice_profile.id).to be < bob_profile.id

      expect(bob_profile.class).to connect_to('user_shard_3.sqlite3')
      bob = User.create(name: "bob")
      expect(bob.class).to connect_to('user_shard_3.sqlite3')
      expect(User.find(1).class).to connect_to('user_shard_2.sqlite3')
      bob.articles << bob_profile
      expect(bob.articles.count).to eq 1
      expect(Article.all_shard.count).to eq 2

      carol = User.create(name: "carol")
      expect(carol.class).to connect_to('user_shard_1.sqlite3')
      carol_profile = Article.new(title: "Carol profile", body: "Carol profile text")
      carol.articles << carol_profile
      expect(carol.articles.count).to eq 1
      expect(Article.all_shard.count).to eq 3

      expect(User.create(name: "dave").class).to connect_to('user_shard_2.sqlite3')
      expect(User.create(name: "ellen").class).to connect_to('user_shard_3.sqlite3')
    end

    it "raise not set user_id(shard key) create record for shard" do
      expect do
        Article.create(title: "Bob profile", body: "Bob profile text")
      end.to raise_error(ActiveRecordSharding::NotFoundShardKeyError, "Please, set user_id.")
    end

    context "Created users and articles" do

      it "one query" do
        # FIXME: write test
        Article.where(user_id: 1).all_shard
      end

      context "Use relation on  user object" do
        it "returns alice's article" do
          article = User.where(name: "alice").all_shard.first.articles.first
          expect(article.class).to eq Article
        end
        it "returns bob's article" do
          article = User.where(name: "bob").all_shard.first.articles.first
          expect(article.class).to eq Article
        end
        it "returns carol's article" do
          article = User.where(name: "carol").all_shard.first.articles.first
          expect(article.class).to eq Article
        end
      end

      it "bob write comment for alice's article" do
        bob = User.where(name: "bob").all_shard.first
        article = User.where(name: "alice").all_shard.first.articles.first
        comment = Comment.create(comment: "Hello, alice.", article: article, user: bob)
        expect(comment.class).to  connect_to('user_shard_2.sqlite3')
        expect(Comment.all_shard.first.user.class).to eq User
      end

      it "#find(Fixnum)" do
        expect(User.find(1).class).to eq User
        expect(User.find(1).id).to eq 1
        expect(User.find(1).name).to eq "alice"
        expect(User.find(2).class).to eq User
        expect(User.find(2).id).to eq 2
        expect(User.find(2).name).to eq "bob"
        expect(User.find(3).class).to eq User
        expect(User.find(3).id).to eq 3
        expect(User.find(3).name).to eq "carol"
      end

      it "#find_by(Fixnum)" do
        expect(User.find_by(1).class).to eq User
        expect(User.find_by(1).id).to eq 1
        expect(User.find_by(1).name).to eq "alice"
        expect(User.find_by(2).class).to eq User
        expect(User.find_by(2).id).to eq 2
        expect(User.find_by(2).name).to eq "bob"
        expect(User.find_by(3).class).to eq User
        expect(User.find_by(3).id).to eq 3
        expect(User.find_by(3).name).to eq "carol"
      end

      # it "#find(Array)" do
      #   pending "will support"
      #   expect(User.find([1, 2, 3]).class).to eq Array
      # end

      it "#all_shard" do
        expect(User.all_shard.class).to eq Array
        expect(User.all_shard.count).to eq 5
        User.all.each do |user|
          expect(user.class).to eq User
        end
      end

      it "#where.#all_shard" do
        alice = User.where(name: "alice").all_shard.first
        expect(alice.class).to eq User
        expect(alice.name).to eq "alice"

        bob = User.where(name: "bob").all_shard.first
        expect(bob.class).to eq User
        expect(bob.name).to eq "bob"

        carol = User.where(name: "carol").all_shard.first
        expect(carol.class).to eq User
        expect(carol.name).to eq "carol"
      end
    end
  end
end
