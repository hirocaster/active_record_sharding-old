require "spec_helper"

require "active_record"

ActiveRecord::Base.logger = Logger.new(STDOUT)

class Book < ActiveRecord::Base
end

class User < ActiveRecord::Base
  use_shard :user
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
  'user_shard_1' => base.merge(database: 'user_shard_1.sqlite3'),
  'user_shard_2' => base.merge(database: 'user_shard_2.sqlite3'),
  'user_shard_3' => base.merge(database: 'user_shard_3.sqlite3'),
  'user_sequence' => base.merge(database: 'user_sequence.sqlite3')
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
    ActiveRecord::Base.establish_connection(:user_sequence).connection.execute('CREATE TABLE user_sequence (id integer primary key autoincrement)')
    ActiveRecord::Base.establish_connection(:user_sequence).connection.execute('INSERT INTO user_sequence (id) VALUES (0)')

    ActiveRecord::Base.establish_connection(:user_shard_1).connection.execute('CREATE TABLE users (id integer primary key autoincrement)')
    ActiveRecord::Base.establish_connection(:user_shard_2).connection.execute('CREATE TABLE users (id integer primary key autoincrement)')
    ActiveRecord::Base.establish_connection(:user_shard_3).connection.execute('CREATE TABLE users (id integer primary key autoincrement)')

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
      expect(User.create.class).to connect_to('user_shard_2.sqlite3')
      expect(User.create.class).to connect_to('user_shard_3.sqlite3')
      expect(User.create.class).to connect_to('user_shard_1.sqlite3')
      expect(User.create.class).to connect_to('user_shard_2.sqlite3')
      expect(User.create.class).to connect_to('user_shard_3.sqlite3')
    end

    context "Created users" do
      it "#find(Fixnum)" do
        expect(User.find(1).class).to eq User
        expect(User.find(1).id).to eq 1
        expect(User.find(2).class).to eq User
        expect(User.find(2).id).to eq 2
        expect(User.find(3).class).to eq User
        expect(User.find(3).id).to eq 3
      end

      it "#find_by(Fixnum)" do
        expect(User.find_by(1).class).to eq User
        expect(User.find_by(1).id).to eq 1
        expect(User.find_by(2).class).to eq User
        expect(User.find_by(2).id).to eq 2
        expect(User.find_by(3).class).to eq User
        expect(User.find_by(3).id).to eq 3
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
    end
  end
end
