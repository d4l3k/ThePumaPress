require 'bundler'
Bundler.require(:default)

DataMapper.setup(:default, 'postgres://postgres:@192.168.1.152/pumapress')

require 'sprockets/environment'
require 'sinatra/sprockets-helpers'
require 'sinatra/asset_pipeline'

Sinatra::Sprockets = Sprockets

configure do
# Logical path to your assets
    set :assets_precompile, %w(default.css default.js *.png *.jpg *.svg *.eot *.ttf *.woff)
    set :assets_prefix, 'assets'
    #sprockets.append_path File.join(root, 'assets', 'stylesheets')
    #sprockets.append_path File.join(root, 'assets', 'javascripts')
    #sprockets.append_path File.join(root, 'assets', 'images')
    register Sinatra::AssetPipeline
end
configure :development do
    Bundler.require(:development)
    set :assets_debug, true
    #use PryRescue::Rack
end
configure :production do
    Bundler.require(:production);
    # CSS minification
    set :assets_css_compressor, :sass

    # JavaScript minification
    set :assets_js_compressor, :closure
end

class Article
  include DataMapper::Resource
    property :id,         Serial
    property :title,      String, :default => ''
    property :image,      Text, :default => ''
    property :body,       Text, :default => ''
    property :published,  Boolean, :default => false
    property :published_on, DateTime
    belongs_to :category
    has n, :users, :through => Resource
    def image_path
        if self.image.length==0
            return "http://i.imgur.com/LbwGoRz.jpg"
        end
        self.image
    end
end

class Category
    include DataMapper::Resource
    property :name,         String, key:true
    property :description,  Text
    property :index,        Integer, :default => 99999
    has n, :articles
end

class User
    include DataMapper::Resource
    property :username,       String, :key => true
    # Access levels are:
    # reader - 0
    # author - 50
    # editor - 100
    property :rank,   Integer, :default => 0
    property :name, String, :default => ""
    property :title, String, :default => "Reader"
    property :about, Text, :default => "No description..."
    property :picture, Text, :default => ""
    property :password, BCryptHash
    has n, :articles, :through => Resource
    def display_name
        if self.name.length > 0
            return self.name
        end
        self.username.upcase
    end
    def display_picture
        if self.picture.length==0
            return "http://i.imgur.com/LbwGoRz.jpg"
        end
        self.picture
    end
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
            flash[:error] = "ERROR: You need to be an author to access that."
            redirect "/"
        end
    end
    def editor_required!
        if not editor?
            flash[:error] = "ERROR: You need to be an editor to access that."
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
get '/article/new' do
    author_required!
    erb :article_new
end

post '/article/:article' do
    author_required!
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
    if params["authors"]
        authors = []
        params["authors"].each do |auth|
            authors.push User.get auth
        end
        document.users = authors
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
class CategoryUnpublished
    def articles *args
        Article.all published:false
    end
    def description
        "All unpublished articles are listed here."
    end
    def name
        "Unpublished Articles"
    end
end
get '/categories' do
    editor_required!
    erb :categories
end
post '/categories' do
    editor_required!
    all_categories = Category.all.map {|cat| cat.name}
    params.each do |cat, data|
        category = Category.first_or_create({name:cat})
        category.index = data["index"].to_i
        category.save
        all_categories.delete cat
    end
    all_categories.each do |cat|
        Category.get(cat).destroy
    end
    "{}"
end
get '/category/*' do
    category_name = params[:splat][0]
    if category_name=="unpublished"
        editor_required!
        @category = CategoryUnpublished.new
        @noedit = true
    else
        @category = Category.get(category_name)
    end
    if !@category
        flash[:error] = "ERROR: Invalid Category."
        redirect '/'
    end
    erb :category
end
post '/category/:category' do
    editor_required!
    category = Category.get params["category"]
    if !category and params["category"] != "new"
        return ""
    end
    response = {}
    if params["category"]=="new"
        category = Category.new params["name"]
    end
    if params["description"]
        category.description = params["description"]
    end
    saved = category.save
    response[:name] = category.name
    response[:saved] = saved
    JSON.dump response
end
get '/article/:article' do
    @article = Article.get(params['article'].to_i)
    if !@article || !author? && !@article.published
        flash[:error]="ERROR: Article not found."
        redirect '/'
    end
    erb :article
end
delete '/article/:article' do
    author_required!
    @article = Article.get(params['article'].to_i)
    if @article
        @article.destroy!
    end
end
get '/user/:user' do
    @user = User.get(params['user'])
    if !@user
        flash[:error]="ERROR: User not found."
    end
    erb :user
end
get '/search' do
    erb :search
end
get '/users' do
    editor_required!
    erb :users
end
post '/user/:user' do
    user = User.get params["user"]
    if !(current_user == user or editor?)
        flash[:error] = "ERROR: Invalid permissions."
        redirect '/'
    end
    response = {}
    if params["name"]
        user.name = params["name"]
    end
    if params["title"]
        user.title = params["title"]
    end
    if params["about"]
        user.about = params["about"]
    end
    if params["picture"]
        user.picture = params["picture"]
    end
    if params["rank"] and editor?
        user.rank = params["rank"].to_i
    end
    saved = user.save
    response[:username] = user.username
    response[:saved] = saved
    JSON.dump response
end
get '/login' do
    if !logged_in?
        erb :login
    else
        flash[:error] = "ERROR: You are already logged in."
        redirect '/'
    end
end
post '/login' do
    redirect_loc = '/'
    if params[:redirect]!=''
        redirect_loc = params[:redirect]
    end
    if authenticate params[:email],params[:password]
        flash[:notice]="Successfully logged in."
        redirect redirect_loc
    else
        flash[:error]="ERROR: Invalid username or password."
        redirect "/login?#{redirect_loc}"
    end
end
get '/logout' do
    if logged_in?
        logout
        flash[:notice]="Successfully logged out."
    end
    redirect '/login'
end

