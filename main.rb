require 'bundler'
Bundler.require

DataMapper.setup(:default, 'postgres://postgres:@192.168.1.152/pumapress')

require 'sinatra/asset_pipeline'
set :assets_precompile, %w(default.css default.js *.png *.jpg *.svg *.eot *.ttf *.woff)

# Logical path to your assets
set :assets_prefix, 'assets'

# Use another host for serving assets
#set :assets_host, '<id>.cloudfront.net'

# Serve assets using this protocol
#set :assets_protocol, :http

# CSS minification
set :assets_css_compressor, :sass

# JavaScript minification
set :assets_js_compressor, :uglifier
register Sinatra::AssetPipeline

class Article
  include DataMapper::Resource
    property :id,         Serial
    property :title,      String, :default => ''
    property :image,      Text, :default => ''
    property :body,       Text, :default => ''
    property :published,  Boolean, :default => false
    property :published_on, DateTime
    belongs_to :category
end

class Category
    include DataMapper::Resource
    property :name,         String, key:true
    property :description,  Text
    has n, :articles
end

class User
    include DataMapper::Resource
    property :username,       String, :key => true
    # Access levels are:
    # user - 0
    # author - 50
    # editor - 100
    property :rank,   Integer, :default => 0
    property :name, String, :default => ""
    property :about, Text, :default => ""
    property :picture, Text, :default => ""
    property :password, BCryptHash
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
    def author_required!
        if not author?
            redirect "/"
        end
    end
    def editor_required!
        if not editor?
            redirect "/"
        end
    end
    def author?
        c_user = current_user
        not c_user.nil? and c_user.rank>=50
    end
    def editor?
        c_user = current_user
        not c_user.nil? and c_user.rank>=100
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
    author_required!
    erb :article_new
end

post '/article/:article' do
    editor_required!
    document = Article.get params["article"].to_i
    response = {}
    if params["article"]=="new"
        document = Article.new #user:current_user
    end
    if params["title"]
        document.title = params["title"]
    end
    if params["body"]
        document.body = params["body"]
    end
    if params["category"]
        document.category = Category.get(params["category"])
    end
    if params["image"]
        document.image = params["image"]
    end
    if params["published"] and editor?
        document.published = params["published"]=='true'
        document.published_on = DateTime.now
    end
    saved = document.save
    response[:id] = document.id
    response[:saved] = saved
    JSON.dump response
end
get '/category/:category' do
    @category = Category.get(params['category'])
    if !@category
        redirect '/'
    end
    erb :category
end
get '/article/:article' do
    @article = Article.get(params['article'].to_i)
    if !@article || !author? && !@article.published
        redirect '/'
    end
    erb :article
end
get '/search' do
    erb :search
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

