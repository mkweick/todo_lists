require 'sinatra'
require 'sinatra/contrib'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'N23JK4H93F78B349IF7UB34'
end

def capitalize(text)
  text.split.map(&:capitalize).join(' ')
end

helpers do
  def flash_message_type(type)
    case type
    when 'success'  then 'flash success'
    when 'error'    then 'flash error'
    else 'flash'
    end
  end

  def completed?(todo)
    todo[:completed]
  end

  def list_complete?(list)
    'complete' if todos?(list) && all_todos_completed?(list)
  end

  def todos?(list)
    list[:todos].any?
  end

  def all_todos_completed?(list)
    list[:todos].all? { |todo| todo[:completed] }
  end

  def todos_completed(list)
    list[:todos].count { |todo| todo[:completed] }
  end
end

before do
  session[:lists] ||= []
  session[:flash] ||= []
end

get '/' do
  redirect '/lists'
end

# Index lists
get '/lists/?' do
  @nav_item = 'new_list'
  @lists = session[:lists]
  erb :lists
end

# New List
get '/lists/new/?' do
  erb :new_list
end

# Return error hash if name invalid. Return nil if name valid.
def error_for_list_name(name)
  if !(1..50).cover?(name.length)
    { type: 'error', text: 'List name must be between 1 and 50 characters.' }
  elsif session[:lists].any? { |list| list[:name] == name }
    { type: 'error', text: 'List name must be unique.' }
  end
end

# Create new list
post '/lists' do
  list_name = capitalize(params[:list_name])
  error = error_for_list_name(list_name)

  if error
    session[:flash] << error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:flash] << { type: 'success', text: "List '#{list_name}' has "\
                                                'been created.' }
    redirect '/lists'
  end
end

# Show list
get '/lists/:id' do
  @nav_item = 'all_lists'
  @slug_list_num = params[:id]
  list_num = @slug_list_num.to_i - 1
  @list = session[:lists][list_num] if list_num >= 0

  if @list
    @todos = []
    session[:lists][list_num][:todos].each_with_index do |todo, idx|
      if todo[:completed]
        @todos.push([idx + 1, todo])
      else
        @todos.unshift([idx + 1, todo])
      end
    end
    erb :show_list
  else
    session[:flash] << { type: 'error', text: "List ##{@slug_list_num} "\
                                              "doesn't exist." }
    redirect '/lists'
  end
end

# Edit list
get '/lists/:id/edit' do
  @slug_list_num = params[:id]
  list_num = @slug_list_num.to_i - 1
  @list = session[:lists][list_num]
  erb :edit_list
end

# Update list
post '/lists/:id' do
  @slug_list_num = params[:id]
  list_num = @slug_list_num.to_i - 1
  list_name = capitalize(params[:list_name])
  
  error = error_for_list_name(list_name)
  if error
    @list = session[:lists][list_num]
    session[:flash] << error
    erb :edit_list
  else
    session[:lists][list_num][:name] = list_name
    session[:flash] << { type: 'success', text: 'List name successfully '\
                                                'updated.' }
    redirect "/lists/#{@slug_list_num}"
  end
end

# Destroy list
post '/lists/:id/destroy' do
  list_num = params[:id].to_i - 1
  list_name = session[:lists][list_num][:name]

  session[:lists].delete_at(list_num)
  session[:flash] << { type: 'success', text: "List '#{list_name}' has "\
                                              'been removed.' }
  redirect '/lists'
end

# Mark all todos complete for a list
post '/lists/:id/complete_all' do
  slug_list_num = params[:id]
  list_num = slug_list_num.to_i - 1
  list = session[:lists][list_num]

  list[:todos].each { |todo| todo[:completed] = true }
  redirect "/lists/#{slug_list_num}"
end

# Create todo
post '/lists/:id/todos' do
  slug_list_num = params[:id]
  list_num = slug_list_num.to_i - 1
  todo_name = params[:todo_name].strip

  if (1..100).cover?(todo_name.length)
    session[:lists][list_num][:todos] << { name: todo_name, complete: false }
    session[:flash] << { type: 'success', text: "Todo '#{todo_name}' has "\
                                                'been added.' }
  else
    session[:flash] << { type: 'error', text: 'Todo must be between 1 '\
                                              'and 100 characters.' }
  end
  redirect "/lists/#{slug_list_num}"
end

# Update todo completed status
post '/lists/:list_id/todos/:id' do
  slug_list_num = params[:list_id]
  list_num = slug_list_num.to_i - 1
  todo_num = params[:id].to_i - 1
  completed_value = params[:completed] == 'true' ? true : false

  session[:lists][list_num][:todos][todo_num][:completed] = completed_value
  redirect "/lists/#{slug_list_num}"
end

# Destroy todo
post '/lists/:list_id/todos/:id/destroy' do
  slug_list_num = params[:list_id]
  list_num = slug_list_num.to_i - 1
  todo_num = params[:id].to_i - 1
  todo_name = session[:lists][list_num][:todos][todo_num][:name]

  session[:lists][list_num][:todos].delete_at(todo_num)
  session[:flash] << { type: 'success', text: "Todo '#{todo_name}' has "\
                                              'been removed.' }
  redirect "/lists/#{slug_list_num}"
end
