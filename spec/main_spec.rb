require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

def app
  Sinatra::Application
end
describe "the puma press" do
    i_suck_and_my_tests_are_order_dependent!
  it "should load the home page successfully" do
    get '/'
    assert last_response.ok?    
  end
  it "should be able to create a category" do
    categ = Category.create(name:"Test",description:"A category to test with")
    assert categ.save
  end
  it "should be able to access a category" do
    categ = Category.get("Test")
    get "/category/#{categ.name}"
    assert last_response.ok?
  end
  it "should be able to create an article" do
    art = Article.create(title:"Test Article", body:"Hi there!", category:Category.get("Test"))
    assert art.save
  end
  it "should not be able to access a unpublished article" do
    art = Article.all(title:"Test Article")[0]
    get "/article/#{art.id}"
    assert last_response.status == 302
  end
  it "should be able to access a published article" do
    art = Article.all(title:"Test Article")[0]
    art.published = true
    art.published_on = DateTime.now
    assert art.save
    get "/article/#{art.id}"
    assert last_response.ok?
  end
  it "should be able to destroy an article and no longer access it" do
    art = Article.all(title:"Test Article")
    id = art.first.id
    art.destroy!
    get "/article/#{id}"
    assert last_response.status == 302
  end
  it "should be able to destroy a category" do
    categ = Category.get("Test")
    assert categ.destroy!
  end
  it "should fail to access new article page" do
    get '/article/new'
    assert last_response.status == 302
  end
  it "should fail to load a nonexistant article" do
    get '/article/999999999999999'
    assert last_response.status == 302
  end
  it "should fail to load a nonexistant category" do
    get '/category/IAMADRUNKDOLPHINONMARSHMELLOWS'
    assert last_response.status == 302
  end
  it "should fail to load the new staff page" do
    get '/staff/new'
    assert last_response.status == 302
  end
  it "should fail to load a nonexistant staff group" do
    get '/staff/2320%20-3201'
    assert last_response.status == 302
  end
  it "should find a login button on the home page" do
    get '/'
    assert last_response.body.include? "Login"
  end
  it "should be able to load a user" do
    get "/user/#{User.first.username}"
    assert last_response.ok?
  end
  it "should fail to load a nonexistant user" do
    get '/user/kasdjflaksdjflasdkjflaksdfj'
    assert last_response.status == 302
  end
end
