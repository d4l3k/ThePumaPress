require 'bundler'
Bundler.require

DataMapper.setup(:default, 'postgres://postgres:@192.168.1.152/pumapress')

class Article
  include DataMapper::Resource
    property :id,         Serial
    property :title,      String, :default => ''
    property :image,      Text, :default => ''
    property :body,       Text, :default => ''
    property :published,  Boolean, :default => false
    property :published_on, DateTime
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
DataMapper.auto_upgrade!

module Helpers
    def current_user
        if logged_in?
            return User.get(session['user'])
        end
        nil
    end
    def editor_required!
        if not editor?
            redirect "/"
        end
    end
    def editor?
        c_user = current_user
        not c_user.nil? and c_user.access_level=="editor"
    end
    def logged_in?
        if !session['userhash'].nil?
            user = UserHash.get(session['userhash'])
            if !user.nil?
                return user.value==session['user']
            end
        end
        false
    end
    def login_required
        if !logged_in?
            redirect "/login?#{env["REQUEST_PATH"]}"
        end
    end
    def authenticate email, pass, expire=nil
        email.downcase!
        email = email.split("@")[0]
        user = User.get(email)
        authed = false
        if !user.nil? && user.password==pass
            authed = true
        else
            b = Curl.post('https://moodle2.universityprep.org/login/index.php',{username:email,password:pass,rememberusername:'1'})
            if b.body_str.include? 'This page should automatically redirect.'
                if user.nil?
                    User.create(username:email,password:pass)
                else
                    user.password = pass
                    user.save
                end
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

helpers Helpers
configure do
    use Rack::Session::Cookie, :expire_after => 60*60*24*7, :secret => "this is hopefully secret"
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

get '/article/new' do
    editor_required!
    erb :article_new
end

post '/article/:article' do
    editor_required!
    document = Article.get params["article"].to_i
    response = {status:'success'}
    if params["article"]=="new"
        document = Article.new user:current_user
    end
    puts params.inspect
    document.title = params["title"]
    document.body = params["body"]
    document.image = params["image"]
    document.save
    response[:id] = document.id
    JSON.dump response
end

get '/article/:article' do
    @article = Article.get(params['article'].to_i)
    if !editor? && !@article.published
        redirect '/'
    end
    erb :article
end

get '/login' do
    if !logged_in?
        erb :login
    else
        redirect '/'
    end
end
post '/login' do
    redirect_loc = '/'
    if params[:redirect]!=''
        redirect_loc = params[:redirect]
    end
    if authenticate params[:email],params[:password]
        redirect redirect_loc
    else
        redirect "/login?#{redirect_loc}"
    end
end
get '/logout' do
    if logged_in?
        logout
    end
    redirect '/login'
end

