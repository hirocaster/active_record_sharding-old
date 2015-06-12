class UsersController < ApplicationController
  def index
    logger.info "Thread(get request):#{Thread.current.to_s}"

    # results = User.find(rand(1..3))

    results = Parallel.map(['a','b','c'], :in_threads=> 3 ) do |one_letter|
                p "Thread:#{Thread.current.to_s}"
                User.find(rand(1..3))
              end

    render :json => results.to_json
  end
end
