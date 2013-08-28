require 'bundler'
Bundler.require

DataMapper.setup(:default, 'postgres://postgres:@192.168.1.152/websync')

class Article
  include DataMapper::Resource
    property :id,         Serial
    property :title,      String
    property :image,      String
    property :body,       Text
    property :created_at, DateTime
    belongs_to :user
end

class User
    include DataMapper::Resource
    property :username,       String, :key => true
    # Access levels are:
    # user
    # editor
    property :access_level,   String, :default => 'user'
    property :name, String, :default => ""
    property :about, Text, :default => ""
    property :picture, Text, :default => ""
    property :password, BCryptHash
    has n, :articles
end

class UserHash
    include DataMapper::Resource
    property :name,  String, :key => true
    property :value,    String
end

DataMapper.finalize
DataMapper.auto_migrate!

helpers do
    def current_user
        if logged_in?
            return User.get(session['user'])
        end
        nil
    end
    def admin_required
        if not admin?
            redirect "/"
        end
    end
    def admin?
        c_user = current_user
        not c_user.nil? and c_user.group=="admin"
    end
    def logged_in?
        (!session['userhash'].nil?)&&UserHash.get(session['userhash']).value==session['user']
    end
    def login_required
        if !logged_in?
            redirect "/login?#{env["REQUEST_PATH"]}"
        end
    end
    def register email, pass
        email.downcase!
        if User.get(email).nil?
            user = User.create({:email=>email,:password=>pass})
            authenticate email, pass
            return user
        elsif authenticate email, pass
            return current_user
        end
        nil
    end
    def authenticate email, pass, expire=nil
        email.downcase!
        user = User.get(email)
        authed = false
        if !user.nil? && user.password==pass
            authed = true
        else
            b = Curl.post('https://moodle2.universityprep.org/login/index.php',{username:username,password:password,rememberusername:'1'})
            if b.body_str.include? 'This page should automatically redirect.'
                if user.nil?
                    User.create
                $redis.set "password:#{username}", hashed_password
                authed = true
            end
        end            
        if authed
            session_key = SecureRandom.uuid
            UserHash.create(name:session_key,value:email)
            session['userhash']=session_key
            session['user']=email
            #if !expire.nil?
            #    $redis.expire("userhash:#{session_key}",expire)
            #end
            return true
        end
        false
    end
    def logout
        UserHash.get(session['userhash']).destroy!
        session['userhash']=nil
        session['user']=nil
    end
    def render_login_button
        if logged_in?
           return '<a href="/logout" title="Sign Out"><i class="icon-signout icon-large"></i><span class="hidden-phone"> Sign Out</span></a>'
        else
           return '<a href="/login" title="Sign In"><i class="icon-signin icon-large"></i><span class="hidden-phone"> Sign In</span></a>'
        end
    end
end

get '/' do
    erb :index
end

get '/user/:user/picture' do
    student = Student.get(param['user']).picture
    if student.nil?
        halt "User not found."
    end
    student.picture
end

get '/article/:article' do
    @article = param['article']
end
