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

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".jpg"
    headers["Content-Type"] = "image/jpeg"
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

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def history_files(path, history_path = "history")
  filename = File.basename(path, ".*")
  extension = File.extname(path)
  directory = File.dirname(path)

  paths = Dir.glob(File.join(directory, history_path, "#{filename}_v*#{extension}"))
  paths.map { |path| File.basename(path) }.sort
end

def next_version_file_path(path, history_path = "history")
  filename = File.basename(path, ".*")
  extension = File.extname(path)
  directory = File.dirname(path)

  versions = Dir.glob(File.join(directory, history_path, "#{filename}_v*#{extension}"))
  next_version_num = if versions.empty?
                       "000"
                     else
                       latest_version = File.basename(versions.max, ".*")
                       sprintf("%03d", latest_version[-3..-1].to_i + 1)
                     end
  name = File.join(history_path, filename + "_v" + next_version_num + extension)
  File.join(directory, name)
end

get "/" do
  file_pattern = File.join(data_path, "*")
  @files = Dir.glob(file_pattern).select do |path|
    File.file?(path)
  end

  @files.map! do |path|
    File.basename(path)
  end

  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new
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

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/:filename" do
  file_path = File.join(data_path, File.basename(params[:filename]))

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, File.basename(params[:filename]))

  if File.extname(file_path) == ".jpg"
    session[:message] = "You can not edit images"
    redirect "/"
  end
  
  if File.file?(file_path)
    @filename = params[:filename]
    @content = File.read(file_path)
    @history_files = history_files(file_path)
  else
    session[:message] = "#{params[filename]} does not exist."
    redirect "/"
  end

  erb :edit
end

post "/new" do
  require_signed_in_user

  filename = params[:filename]
  message = validate_filename(filename)
  
  unless message == ""
    session[:message] = message
    status 422
    erb :new
  else
    create_document(filename)
    session[:message] = "#{filename} has been created."
    redirect "/"
  end
end

post "/uploadimage" do
  require_signed_in_user

  if params[:image]
    filename = params[:image][:filename]
    image_data = params[:image][:tempfile]
  else
    session[:message] = "Please upload an image"
    status 422
    halt erb :new
  end

  unless File.extname(filename) == ".jpg"
    session[:message] = "unsupported format (supports: .jpg)"
    status 422
    erb :new
  else
    File.open(File.join(data_path, filename), "wb") do |file|
      file.write(image_data.read)
    end
    session[:message] = "#{filename} has been uploaded."
    redirect "/"
  end
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, File.basename(params[:filename]))
  new_content = params[:content]
  base_content = File.read(file_path)
  
  if !File.file?(file_path)
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  elsif new_content == base_content
    session[:message] = "No changes were made."
    redirect "/"
  else
    File.write(file_path, new_content)
    File.write(next_version_file_path(file_path), base_content)
    session[:message] = "#{params[:filename]} has been updated."
    redirect "/"
  end
end

post "/:filename/duplicate" do
  require_signed_in_user

  filename = File.basename(params[:filename])
  file_path = File.join(data_path, filename)

  if File.extname(file_path) == ".jpg"
    session[:message] = "Image files can not be duplicated"
    redirect "/"
  end

  content = File.read(file_path)
  new_filename = filename + "_copy"

  create_document(new_filename, content)
  session[:message] = "#{new_filename} has been created."

  redirect "/#{new_filename}/edit"
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, File.basename(params[:filename]))

  if !File.file?(file_path)
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  elsif
    File.delete(file_path)
    session[:message] = "#{params[:filename]} has been deleted."
    redirect "/"
  end
end

get "/:filename/history" do
  require_signed_in_user

  @filename = File.basename(params[:filename])
  file_path = File.join(data_path, @filename)
  @history_files = history_files(file_path)

  erb :history
end

get "/:filename/history/:history_file" do
  require_signed_in_user

  @filename = File.basename(params[:history_file])
  file_path = File.join(data_path, "history", @filename)
  load_file_content(file_path)
end

post "/:filename/history/:history_file/restore" do
  require_signed_in_user

  base_path = File.join(data_path, File.basename(params[:filename]))
  history_path = File.join(data_path, "history", File.basename(params[:history_file]))
  base_content = File.read(base_path)
  history_content = File.read(history_path)

  File.write(next_version_file_path(base_path), base_content)
  File.write(base_path, history_content)
  File.delete(history_path)
  session[:message] = "#{params[:history_file]} has been restored to #{params[:filename]}."
  redirect "/"
end