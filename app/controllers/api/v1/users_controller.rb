module Api::V1
  class UsersController < BaseController
    # User name and password needed to access the users controller API and send
    # requests

    #http_basic_authenticate_with name: "admin", password: "Az2L%r[S";

    #use this to authenticate
    #include DeviseTokenAuth::Concerns::SetUserByToken
    #before_action :authenticate_user!
    before_action :authenticate_with_token!, only: [:update, :destroy]
    #before_filter :authenticate_user!

    # GET show all users
    def index
      users = User.all
      if name = params[:name]
        users = User.where(name: name)
      end
      render json: users, status: :ok
    end

    # GET show specific user
    def show
      user = User.find(params[:id])

      if !user.nil?
        render json: user, status: :ok
      else
        render json: {
          error: "No such user; check the user id",
          status: 400
        }, status: 400
      end
    end

    # curl -i -X POST -d 'users[email]=masteryoda@hotmail.com&users[password]=1234567890' http://localhost:3000/api/v1/users
    def create
      user = User.new(user_params)

      if user.save
        render nothing: true, status: 204#, location: user
      else
        render json: user.errors, status: 422
      end
    end

    # DELETE destroy user and its association
    def destroy
      user = current_user

      if !user.nil?
        User.destroy(params[:id])
        head :no_content
      else
        render json: {
          error: "No such user; check the user id",
          status: 400
        }, status: 400
      end
    end

    # curl -X PUT --header "Authorization: amojcUyMjJZPRqrnPtKy" -d 'users[name]=tony' http://localhost:3000/api/v1/users/1
    def update
      user = current_user #User.find(params[:id])

      if user.update(user_params)

        render json: user, status: 200#, location: [:api, user]
      else
        render json: { errors: user.errors }, status: 422
      end
    end

    private

      def user_params
        params.require(:users).permit(:email, :password, :password_confirmation,
        :name, :surname, :phone_number, :phone_verified)
      end

  end
end
