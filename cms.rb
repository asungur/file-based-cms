require "yaml"
require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
   set :erb, escape_html: true
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def image_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/images", __FILE__)
  else
    File.expand_path("../images", __FILE__)
  end
end 

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def add_user_credentials(username, password)
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  bcrypt_password = BCrypt::Password.create(password).to_s
  credentials = YAML.load_file(credentials_path).to_h
  credentials[username] = bcrypt_password
  File.write(credentials_path, credentials.to_yaml)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def validate_filename(name)
  if name.size == 0
    return "A name is required."
  elsif name.match(/\.(txt|md)$/)
    name_only = name.gsub(/\.(txt|md)$/, '')
    if name_only.match(/(\\|\/|:|\*|\?|"|<|>|\|)/)
      return "File name can must contain /\:*?\"<>|"
    else
      return ""
    end
  else
    return "Invalid/missing extension"
  end
end

def validate_imagename(name)
  if name.size == 0
    return "A name is required."
  elsif name.match(/\.(jpg|gif)$/)
    name_only = name.gsub(/\.(jpg|gif)$/, '')
    if name_only.match(/(\\|\/|:|\*|\?|"|<|>|\|)/)
      return "Image name can must contain /\:*?\"<>|"
    else
      return ""
    end
  else
    return "Invalid/missing extension"
  end
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  file_pattern = File.join(data_path, "*")
  image_pattern = File.join(image_path, "*")
  @files = Dir.glob(file_pattern).map { |path| File.basename(path) }
  @images = Dir.glob(image_pattern).map { |path| File.basename(path) }
  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new
end

post "/create" do
  require_signed_in_user

  filename = params[:filename].to_s
  
  message = validate_filename(filename)
  
  unless message == ""
    session[:message] = message
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created."

    redirect "/"
  end
end

get "/upload" do
  require_signed_in_user
  erb :upload
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/upload" do
  require_signed_in_user

  imagename = params[:file][:filename].to_s

  message = validate_imagename(imagename)

  unless message == ""
    session[:message] = message
    status 422
    erb :upload
  else
    file_path = File.join(image_path, imagename)
    tempfile = params[:file][:tempfile]

    File.open(file_path, 'wb') { |file| file.write(tempfile.read) }
    session[:message] = "#{imagename} has been uploaded."

    redirect "/"
  end
end

post "/:filename/duplicate" do
  require_signed_in_user

  filename = params[:filename]
  filename = filename.split(".").insert(1, "_copy.").join('')

  file_path = File.join(data_path, filename)
  source_path = File.join(data_path, params[:filename])
  source_content =File.read(source_path)

  File.write(file_path, source_content)
  session[:message] = "#{params[:filename]} has been duplicated."

  redirect "/"
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

get "/users/signup" do
  erb :signup
end

get "/images/:image" do
  erb params[:image]
end

post "/users/signup" do
  username = params[:username]
  password = params[:password]
  add_user_credentials(username,password)

  session[:message] = "You have successfully registered" 
  redirect "/"
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end
