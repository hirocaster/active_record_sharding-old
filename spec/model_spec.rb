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

system "mysql -u root -e 'create database active_record_shard_default_test;'"
system "mysql -u root -e 'create database user_shard_1_test;'"
system "mysql -u root -e 'create database user_shard_2_test;'"
system "mysql -u root -e 'create database user_shard_3_test;'"
system "mysql -u root -e 'create database user_user_sequence_test;'"
system "mysql -u root -e 'create database user_article_sequence_test;'"
system "mysql -u root -e 'create database user_comment_sequence_test;'"

base = { adapter: 'mysql2'}

ActiveRecord::Base.configurations = {
  'default' => base.merge(database: 'active_record_shard_default_test'),
  'user_shard_1_test' => base.merge(database: 'user_shard_1_test'),
  'user_shard_2_test' => base.merge(database: 'user_shard_2_test'),
  'user_shard_3_test' => base.merge(database: 'user_shard_3_test'),
  'user_user_sequence_test'    => base.merge(database: 'user_user_sequence_test'),
  'user_article_sequence_test' => base.merge(database: 'user_article_sequence_test'),
  'user_comment_sequence_test' => base.merge(database: 'user_comment_sequence_test')
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
        create_sequencer_table_sql = "CREATE TABLE #{sequence.to_s} (id BIGINT unsigned NOT NULL DEFAULT 0)"
        ActiveRecord::Base.establish_connection(db_conn_name).connection.execute create_sequencer_table_sql
        ActiveRecord::Base.establish_connection(db_conn_name).connection.execute("INSERT INTO #{sequence.to_s} (id) VALUES (0)")
      end
    end

    create_users_sql = "CREATE TABLE users (`id` INT(11) NOT NULL auto_increment, `name` VARCHAR(255), PRIMARY KEY (`id`))"
    ActiveRecord::Base.establish_connection(:user_shard_1_test).connection.execute create_users_sql
    ActiveRecord::Base.establish_connection(:user_shard_2_test).connection.execute create_users_sql
    ActiveRecord::Base.establish_connection(:user_shard_3_test).connection.execute create_users_sql

    create_articles_sql = "CREATE TABLE articles (`id` INT(11) NOT NULL auto_increment, `user_id` INT(11), `title` VARCHAR(255), `body` VARCHAR(255), PRIMARY KEY (`id`))"
    ActiveRecord::Base.establish_connection(:user_shard_1_test).connection.execute create_articles_sql
    ActiveRecord::Base.establish_connection(:user_shard_2_test).connection.execute create_articles_sql
    ActiveRecord::Base.establish_connection(:user_shard_3_test).connection.execute create_articles_sql

    comments_table_query = "CREATE TABLE comments (`id` INT(11) NOT NULL auto_increment, `user_id` INT(11), `article_id` INT(11), `comment` VARCHAR(255), PRIMARY KEY (`id`))"
    ActiveRecord::Base.establish_connection(:user_shard_1_test).connection.execute comments_table_query
    ActiveRecord::Base.establish_connection(:user_shard_2_test).connection.execute comments_table_query
    ActiveRecord::Base.establish_connection(:user_shard_3_test).connection.execute comments_table_query

    ActiveRecord::Base.establish_connection(:default)
    Book.connection.execute("CREATE TABLE books (`id` INT(11) NOT NULL auto_increment, PRIMARY KEY (`id`))")
  end

  config.after(:suite) do
    system "mysql -u root -e 'drop database active_record_shard_default_test;'"
    system "mysql -u root -e 'drop database user_shard_1_test;'"
    system "mysql -u root -e 'drop database user_shard_2_test;'"
    system "mysql -u root -e 'drop database user_shard_3_test;'"
    system "mysql -u root -e 'drop database user_user_sequence_test;'"
    system "mysql -u root -e 'drop database user_article_sequence_test;'"
    system "mysql -u root -e 'drop database user_comment_sequence_test;'"
  end
end

RSpec.describe ActiveRecordSharding::Model do

  before(:each) do
    allow(ActiveRecordSharding::Config).to receive(:file) { "./spec/shards.yml" }
    ActiveRecordSharding::Config.load!
  end

  it "default connection" do
    expect(Book).to connect_to "active_record_shard_default_test"
  end

  context "User sharding" do
    it "shard_1, shard_2, shard_3" do
      alice = User.create(name: "alice")
      expect(alice.class).to connect_to "user_shard_2_test"

      alice_profile = Article.new(title: "Alice profile", body: "Alice profile text")
      alice.articles << alice_profile
      expect(alice_profile.class).to connect_to "user_shard_2_test"
      expect(alice.articles.count).to eq 1

      bob_profile = Article.create(title: "Bob profile", body: "Bob profile text", user_id: 2)

      expect(alice_profile.id).not_to eq bob_profile.id
      expect(alice_profile.id).to be < bob_profile.id

      expect(bob_profile.class).to connect_to "user_shard_3_test"
      bob = User.create(name: "bob")
      expect(bob.class).to connect_to "user_shard_3_test"
      expect(User.find(1).class).to connect_to "user_shard_2_test"
      bob.articles << bob_profile
      expect(bob.articles.count).to eq 1
      expect(Article.all_shard.count).to eq 2

      carol = User.create(name: "carol")
      expect(carol.class).to connect_to "user_shard_1_test"
      carol_profile = Article.new(title: "Carol profile", body: "Carol profile text")
      carol.articles << carol_profile
      expect(carol.articles.count).to eq 1
      expect(Article.all_shard.count).to eq 3

      expect(User.create(name: "dave").class).to connect_to "user_shard_2_test"
      expect(User.create(name: "ellen").class).to connect_to "user_shard_3_test"
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
        expect(comment.class).to  connect_to "user_shard_2_test"
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
