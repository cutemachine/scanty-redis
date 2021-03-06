require 'rubygems'
require 'sinatra'

require File.dirname(__FILE__) + '/lib/all'

configure do
	Blog = OpenStruct.new(
		:title => ENV['TITLE'] || 'a scanty blog on redis',
		:author => ENV['AUTHOR'] || 'John Doe',
		:url_base => ENV['URL_BASE'] || 'http://localhost:4567/',
		:admin_password => ENV['ADMIN_PASSWORD'] || 'changeme',
		:admin_cookie_key => 'scanty_admin',
		:admin_cookie_value => ENV['ADMIN_COOKIE_VALUE'] || '51d6d976913ace58',
		:disqus_shortname => nil
	)
end

error do
	e = request.env['sinatra.error']
	puts e.to_s
	puts e.backtrace.join("\n")
	"Application error"
end

helpers do
	def admin?
		request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
	end

	def auth
		stop [ 401, 'Not authorized' ] unless admin?
	end

	def cache_page(seconds=5*60)
		response['Cache-Control'] = "public, max-age=#{seconds}" unless development?
	end
end

layout 'layout'

### Public

get '/' do
	cache_page
	posts = Post.find_range(0, 10)
	erb :index, :locals => { :posts => posts }, :layout => false
end

get '/past/:year/:month/:day/:slug/' do
	cache_page
	post = Post.find_by_slug(params[:slug])
	stop [ 404, "Page not found" ] unless post
	@title = post.title
	erb :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
	cache_page
	redirect "/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/", 301
end

get '/past' do
	cache_page
	posts = Post.all
	@title = "Archive"
	erb :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
	cache_page
	tag = params[:tag].downcase.strip
	posts = Post.find_tagged(tag)
	@title = "Posts tagged #{tag}"
	erb :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
	cache_page
	@posts = Post.find_range(0, 10)
	content_type 'application/atom+xml', :charset => 'utf-8'
	builder :feed
end

get '/rss' do
	cache_page
	redirect '/feed', 301
end

### Admin

get '/auth' do
	erb :auth
end

post '/auth' do
	set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value) if params[:password] == Blog.admin_password
	redirect '/'
end

get '/posts/new' do
	auth
	erb :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
	auth
	post = Post.create :title => params[:title], :tags => params[:tags], :body => params[:body], :created_at => Time.now, :slug => Post.make_slug(params[:title])
	redirect post.url
end

get '/past/:year/:month/:day/:slug/edit' do
	auth
	post = Post.find_by_slug(params[:slug])
	stop [ 404, "Page not found" ] unless post
	erb :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
	auth
	post = Post.find_by_slug(params[:slug])
	stop [ 404, "Page not found" ] unless post
	post.title = params[:title]
	post.tags = params[:tags]
	post.body = params[:body]
	post.save
	redirect post.url
end

