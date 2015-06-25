require "spec_helper"

require "active_record"
require "parallel"

ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecordSharding::Config.file = "./spec/shards.yml"

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


[Book, User, ActiveRecord::Base].each do |model|
  if model.connected?
    raise "ActiveRecord::Base didn't establish connection lazily!"
  end
end

[:user_user_sequence_test, :user_article_sequence_test, :user_comment_sequence_test].each do |db_conn_name|
  [:user_user_sequence, :user_article_sequence, :user_comment_sequence].each do |sequence|
    drop_table_sql = "DROP TABLE IF EXISTS #{sequence.to_s}"
    create_sequencer_table_sql = "CREATE TABLE #{sequence.to_s} (id BIGINT unsigned NOT NULL DEFAULT 0)"

    ActiveRecord::Base.establish_connection(db_conn_name).connection.execute drop_table_sql
    ActiveRecord::Base.establish_connection(db_conn_name).connection.execute create_sequencer_table_sql
    ActiveRecord::Base.establish_connection(db_conn_name).connection.execute("INSERT INTO #{sequence.to_s} (id) VALUES (0)")
  end
end

drop_table_users_sql = "DROP TABLE IF EXISTS users"
create_users_sql = "CREATE TABLE users (`id` INT(11) NOT NULL auto_increment, `name` VARCHAR(255), PRIMARY KEY (`id`))"

drop_table_articles_sql = "DROP TABLE IF EXISTS articles"
create_articles_sql = "CREATE TABLE articles (`id` INT(11) NOT NULL auto_increment, `user_id` INT(11), `title` VARCHAR(255), `body` VARCHAR(255), PRIMARY KEY (`id`))"

drop_table_comments_sql = "DROP TABLE IF EXISTS comments"
create_comments_sql = "CREATE TABLE comments (`id` INT(11) NOT NULL auto_increment, `user_id` INT(11), `article_id` INT(11), `comment` VARCHAR(255), PRIMARY KEY (`id`))"

[:user_shard_1_test, :user_shard_2_test, :user_shard_3_test].each do |db_conn_name|
  ActiveRecord::Base.establish_connection(db_conn_name).connection.execute drop_table_users_sql
  ActiveRecord::Base.establish_connection(db_conn_name).connection.execute create_users_sql

  ActiveRecord::Base.establish_connection(db_conn_name).connection.execute drop_table_articles_sql
  ActiveRecord::Base.establish_connection(db_conn_name).connection.execute create_articles_sql

  ActiveRecord::Base.establish_connection(db_conn_name).connection.execute drop_table_comments_sql
  ActiveRecord::Base.establish_connection(db_conn_name).connection.execute create_comments_sql
end


ActiveRecord::Base.establish_connection(:default)
ActiveRecord::Base.connection # Create connection

create_books_sql = "CREATE TABLE books (`id` INT(11) auto_increment, `name` VARCHAR(255), PRIMARY KEY (`id`))"
ActiveRecord::Base.connection.execute create_books_sql

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
    ActiveRecord::Base.establish_connection(:default)
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
    ActiveRecordSharding::Config.load!
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

    context "Article belongs_to User shard object" do
      it "raise not set user_id(shard key) create record for shard" do
        expect do
          Article.create(title: "Bob profile", body: "Bob profile text")
        end.to raise_error(ActiveRecordSharding::NotFoundShardKeyError, "Please, set user_id.")
      end
    end

    context "Created users and articles" do

      it "bob write comment for alice's article" do
        bob = User.where(name: "bob").all_shard.first
        article = User.where(name: "alice").all_shard.first.articles.first
        comment = Comment.create(comment: "Hello, alice.", article: article, user: bob)
        expect(comment.class).to  connect_to "user_shard_2_test"
        expect(Comment.find(comment.id).user.class).to eq User
      end

      it "carol write comment for bob's article" do
        carol = User.where(name: "carol").all_shard.first
        article = User.where(name: "bob").all_shard.first.articles.first
        comment = Comment.create(comment: "Hello, bob.", article: article, user: carol)
        expect(comment.class).to  connect_to "user_shard_3_test"
        expect(Comment.find(comment.id).user.class).to eq User
      end

      it "alice write comment for carol's article" do
        alice = User.where(name: "alice").all_shard.first
        article = User.where(name: "carol").all_shard.first.articles.first
        comment = Comment.create(comment: "Hello, carol.", article: article, user: alice)
        expect(comment.class).to  connect_to "user_shard_1_test"
        expect(Comment.find(comment.id).user.class).to eq User
      end

      it "one query" do
        # FIXME: write test
        Article.where(user_id: 1).all_shard
      end

      describe "#exsists?" do
        context "not shard object" do

          it "returns true" do
            book = Book.create
            expect(Book.exists?).to be true
            expect(Book.exists?(book.id)).to be true
          end

          it "returns false" do
            expect(Book.exists?(false)).to be false
            Book.create
            expect(Book.exists?(Book.last.id + 1)).to be false
          end
        end

        context "shard object" do
          it "returns true, User#exists?(Fixnum)" do
            expect(User.exists?(1)).to be true
            expect(User.exists?(2)).to be true
            expect(User.exists?(3)).to be true
          end

          it "returns true, Article#exists?(Fixnum)" do
            expect(Article.exists?(1)).to be true
            expect(Article.exists?(2)).to be true
            expect(Article.exists?(3)).to be true
          end

          it "returns true, Comment#exists?(Fixnum)" do
            expect(Comment.exists?(1)).to be true
            expect(Comment.exists?(2)).to be true
            expect(Comment.exists?(3)).to be true
          end

          it "returns true, User#exists?(Array)" do
            expect(User.exists?(['name LIKE ?', "%ali%"])).to be true
            expect(User.exists?(['name LIKE ?', "%bo%"])).to be true
            expect(User.exists?(['name LIKE ?', "%ca%"])).to be true
          end

          it "returns true, Article#exists?(Array)" do
            expect(Article.exists?(['title LIKE ?', "%ali%"])).to be true
            expect(Article.exists?(['title LIKE ?', "%bo%"])).to be true
            expect(Article.exists?(['title LIKE ?', "%ca%"])).to be true
          end

          it "returns true, Comment#exists?(Array)" do
            expect(Comment.exists?(['comment LIKE ?', "%ali%"])).to be true
            expect(Comment.exists?(['comment LIKE ?', "%bo%"])).to be true
            expect(Comment.exists?(['comment LIKE ?', "%ca%"])).to be true
          end

          it "returns true, User#exists?(Hash)" do
            expect(User.exists?(name: "alice")).to be true
            expect(User.exists?(name: "bob")).to be true
            expect(User.exists?(name: "carol")).to be true
            expect(User.exists?(id: [1, 2])).to be true
          end

          it "returns true, Article#exists?(Hash)" do
            expect(Article.exists?(title: "Alice profile")).to be true
            expect(Article.exists?(title: "Bob profile")).to be true
            expect(Article.exists?(title: "Carol profile")).to be true
            expect(Article.exists?(id: [1, 2])).to be true
          end

          it "returns true, Comment#exists?(Hash)" do
            expect(Comment.exists?(comment: "Hello, alice.")).to be true
            expect(Comment.exists?(comment: "Hello, bob.")).to be true
            expect(Comment.exists?(comment: "Hello, carol.")).to be true
          end

          it "returns false, etc" do
            expect(User.exists?(false)).to be false
            expect(User.exists?('test')).to be false
            expect(User.exists?(id: [1, 99])).to be false
            expect(Article.exists?(false)).to be false
            expect(Article.exists?('test')).to be false
            expect(Article.exists?(id: [1, 99])).to be false
            expect(Comment.exists?(false)).to be false
            expect(Comment.exists?('test')).to be false
            expect(Comment.exists?(id: [1, 99])).to be false
          end

          it "returns raise" do
            expect { Article.find(99999) }.to raise_error(ActiveRecord::RecordNotFound)
            expect { Comment.find(99999) }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end

      describe "#find(Array)" do
        it "raise exception ActiveRecord::RecordNotFound" do
          expect { User.find([99999]) }.to raise_error(ActiveRecord::RecordNotFound)
          expect { User.find([99999, 999]) }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it "returns User object in Array" do
          result = User.find([1])
          expect(result.class).to eq Array
          expect(result.count).to eq 1
          expect(result[0].class).to eq User
          expect(result[0].id).to eq 1
          expect(result[0].name).to eq "alice"
        end

        it "returns User objects in Array" do
          result = User.find([1, 2])
          expect(result.class).to eq Array
          expect(result.count).to eq 2
          expect(result[0].class).to eq User
          expect(result[1].class).to eq User
          expect(result[0].id).to eq 1
          expect(result[1].id).to eq 2
          expect(result[0].name).to eq "alice"
          expect(result[1].name).to eq "bob"

          result = User.find([1, 2, 3])
          expect(result.count).to eq 3
        end

        it "returns sorted User objects in Array" do
          result = User.find([2, 1])
          expect(result[0].id).to eq 1
          expect(result[1].id).to eq 2
        end

        it "raise exception ActiveRecord::RecordNotFound found 1,2 but not found 9" do
          expect { User.find([1, 2, 9]) }.to raise_error(ActiveRecord::RecordNotFound)
        end
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

      context "multi process" do
        it "#find by 3 process" do
          Parallel.map(['a','b','c'], in_processes: 3) do
            find_id = rand(1..3)
            User.find(find_id)
          end
        end
      end

      context "multi thread" do
        it "#find by 3 thread" do
          Parallel.map(['a','b','c'], in_threads: 3) do
            find_id = rand(1..3)
            User.find(find_id)
          end
        end
      end
    end
  end
end
