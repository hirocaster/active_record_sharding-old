class User < ActiveRecord::Base
  use_shard :user
end
