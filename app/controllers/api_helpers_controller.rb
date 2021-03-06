class ApiHelpersController < ApplicationController
	skip_before_action :verify_authenticity_token

	# Creating a user
	# Parameters must include
	# user => [email, username, password, password_confirmation]
	def user_create
		respond_to do |format|
			new_user = User.new params.require(:user).permit(:username, :email, :password, :password_confirmation)
			if User.where(:email => new_user.email).count > 0
				format.json { render json: { "error" => "Email ID already taken!" }, status: 400 }
			elsif User.where(:username => new_user.username).count > 0
				format.json { render json: { "error" => "Username already taken!" }, status: 400 }
			elsif new_user.password != new_user.password_confirmation
				format.json { render json: { "error" => "Passwords don't match! Check, and try again." }, status: 400 }
			elsif new_user.save
				format.json { render json: { "res" => new_user }, status: :created }
			else
				format.json { render json: { "error" => "Error while creation!"}, status: 500 }
			end
		end
	end

	# Signing in a user
	# params must include
	# auth_data (== email || == username), auth_password ( == user.password)
	def user_signin
		if not params.keys.include? "auth_data" or not params.keys.include? "auth_password"
			respond_to do |format1|
				format1.json { render json: { "msg" => "Invalid parameters! Fill in Username / Email and Password." }, status: 400 }
			end
		end
		respond_to do |format|
			# figure out if a user exists
			# Login with Username and Email both are supported
			if User.where(:email => params[:auth_data]).count > 0
				this_user = User.where(:email => params[:auth_data]).first
			elsif User.where(:username => params[:auth_data]).count > 0
				this_user = User.where(:username => params[:auth_data]).first
			else
				format.json { render json: { "error" => "User not found!" }, status: 400 }
			end
			if this_user != nil
				if this_user.valid_password?(params[:auth_password])
					# create the session for the user
					this_session = Session.new
					this_session.user_id = this_user.id
					this_session.sid = OpenSSL::Digest::SHA256.new((Time.now.to_i + Random.new(Time.now.to_i).rand(1e3)).to_s).hexdigest
					if this_session.save!
						format.json { render json: { "msg" => "Successfully logged in!", "res" => { "session" => this_session, "user" => this_user } }, status: 200 }
					else
						format.json { render json: { "error" => "Server error, while creating a session!" }, status: 500 }
					end
				else
					# bad password
					format.json { render json: { "error" => "Bad password!" }, status: 401 }
				end
			end
		end
	end

	# Creating an article from the parameters
	# params must include
	# sid, link (URL to the article), authors, quote
	def article_create
		puts "Paramas doesn't have SID: #{params_doesnt_have_sid params}"
		respond_to do |format|
			if params_doesnt_have_sid params
				format.json { render json: { "error" => "You must provide a session ID!" }, status: 401 }
			else
				user_id = get_user_id params[:sid]
				if user_id
					new_article = User.find(user_id).articles.new
					new_article.link = params[:link]
					new_article.quote = params[:quote]
					new_article.author = params[:authors]
					if new_article.save!
						format.json {render json: { "msg" => "Article created!", "res" => new_article }, status: 201 }
					else
						format.json { render json: { "error" => "Server error! Try again in some time." }, status: 500 }
					end
				else
					format.json { render json: { "error" => "Session timed out!" }, status: 401 }
				end
			end
		end
	end

	# List all the articles for the signed in user
	# Params must include
	# sid
	def articles_list
		respond_to do |format|
			if params_doesnt_have_sid params
				format.json { render json: { "error" => "You must provide a session ID!" }, status: 401 }
			else
				user_id = get_user_id params[:sid]
				if user_id
					format.json { render json: { "res" => User.find(user_id).articles }, status: 200 }
				else
					format.json { render json: { "error" => "Session timed out!" }, status: 401 }
				end
			end
		end
	end

	private
	def get_user_id(sid)
		this_session = Session.where("created_at > ?", 10.minutes.ago).where(:sid => sid)
		if this_session.count > 0
			this_session.first.user_id
		else
			nil
		end
	end

	private
	def params_doesnt_have_sid(params)
		not params.keys.include? "sid"
	end
end
