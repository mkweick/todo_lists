require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'N23JK4H93F78B349IF7UB34'
  set :erb, escape_html: true
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

  def list_complete?(list)
    todos?(list) && all_todos_completed?(list)
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def sort_lists(lists)
    completed, incomplete = lists.partition { |list| list_complete?(list) }

    incomplete.each { |list| yield list, lists.index(list) + 1 }
    completed.each { |list| yield list, lists.index(list) + 1 }
  end

  def todo_class(todo)
    'complete' if todo[:completed]
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

  def sort_todos(todos)
    completed, incomplete = todos.partition { |todo| todo[:completed] }

    incomplete.each { |todo| yield todo, todos.index(todo) + 1 }
    completed.each { |todo| yield todo, todos.index(todo) + 1 }
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

# Return list if valid list. Else redirect to lists and display flash error.
def load_list(list_num)
  list = session[:lists][list_num] if list_num && list_num >= 0
  return list if list

  session[:flash] << { type: 'error', text: 'The specified list was '\
                                            'not found.' }
  redirect '/lists'
  halt
end

# Show list
get '/lists/:id' do
  @slug_list_num = params[:id]
  list_num = @slug_list_num.to_i - 1
  @list = load_list(list_num)
  @todos = @list[:todos]
  erb :show_list
end

# Edit list
get '/lists/:id/edit' do
  @slug_list_num = params[:id]
  list_num = @slug_list_num.to_i - 1
  @list = load_list(list_num)
  erb :edit_list
end

# Update list
post '/lists/:id' do
  @slug_list_num = params[:id]
  list_num = @slug_list_num.to_i - 1
  @list = load_list(list_num)

  list_name = capitalize(params[:list_name])
  error = error_for_list_name(list_name)
  if error
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
  list = load_list(list_num)

  session[:lists].delete_at(list_num)
  session[:flash] << { type: 'success', text: "List '#{list[:name]}' has "\
                                              'been removed.' }
  redirect '/lists'
end

# Mark all todos complete for a list
post '/lists/:id/complete_all' do
  slug_list_num = params[:id]
  list_num = slug_list_num.to_i - 1
  list = load_list(list_num)

  list[:todos].each { |todo| todo[:completed] = true }
  session[:flash] << { type: 'success', text: 'All todos marked completed' }
  redirect "/lists/#{slug_list_num}"
end

# Create todo
post '/lists/:id/todos' do
  slug_list_num = params[:id]
  list_num = slug_list_num.to_i - 1
  list = load_list(list_num)

  todo_name = params[:todo_name].strip
  if (1..100).cover?(todo_name.length)
    list[:todos] << { name: todo_name, complete: false }
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
  list = load_list(list_num)
  todo_num = params[:id].to_i - 1

  completed_value = params[:completed] == 'true'
  list[:todos][todo_num][:completed] = completed_value
  redirect "/lists/#{slug_list_num}"
end

# Destroy todo
post '/lists/:list_id/todos/:id/destroy' do
  slug_list_num = params[:list_id]
  list_num = slug_list_num.to_i - 1
  list = load_list(list_num)
  todo_num = params[:id].to_i - 1
  todo_name = list[:todos][todo_num][:name]

  session[:lists][list_num][:todos].delete_at(todo_num)
  session[:flash] << { type: 'success', text: "Todo '#{todo_name}' has "\
                                              'been removed.' }
  redirect "/lists/#{slug_list_num}"
end
