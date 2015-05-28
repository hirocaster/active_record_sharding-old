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
    binding.pry
  end
end
