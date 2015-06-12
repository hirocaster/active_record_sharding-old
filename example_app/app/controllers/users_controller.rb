class UsersController < ApplicationController
  def index
    render :json => User.all_shard.to_json
  end
end
