# Person CRUD — single-file three-tier Sinatra app.
# Run:  bundle exec ruby app.rb   (or)   ruby app.rb
# Deps: sinatra, sqlite3
require 'sinatra'
require 'sqlite3'
require 'date'

# ---------- Data tier ----------
DB = SQLite3::Database.new(File.join(__dir__, 'people.db'))
DB.results_as_hash = true
DB.execute <<~SQL
  CREATE TABLE IF NOT EXISTS people (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name TEXT    NOT NULL,
    last_name  TEXT    NOT NULL,
    dob        TEXT    NOT NULL
  );
SQL

if DB.get_first_value('SELECT COUNT(*) FROM people').zero?
  # The Flintstones first aired in 1960, so we pretend the cast was born then.
  [
    ['Fred',   'Flintstone', '1960-09-30'],
    ['Wilma',  'Flintstone', '1960-10-07'],
    ['Barney', 'Rubble',     '1960-11-04'],
    ['Betty',  'Rubble',     '1960-12-02'],
    ['Pebbles','Flintstone', '1963-02-22'],
  ].each { |row| DB.execute('INSERT INTO people (first_name,last_name,dob) VALUES (?,?,?)', row) }
end

# ---------- Domain / service tier ----------
module People
  module_function

  def all       = DB.execute('SELECT * FROM people ORDER BY id')
  def find(id)  = DB.execute('SELECT * FROM people WHERE id=?', id).first
  def create(a) = DB.execute('INSERT INTO people (first_name,last_name,dob) VALUES (?,?,?)', [a[:first_name], a[:last_name], a[:dob]])
  def update(id, a) = DB.execute('UPDATE people SET first_name=?,last_name=?,dob=? WHERE id=?', [a[:first_name], a[:last_name], a[:dob], id])
  def delete(id) = DB.execute('DELETE FROM people WHERE id=?', id)

  def validate(a)
    errs = []
    errs << 'First name is required.' if a[:first_name].to_s.strip.empty?
    errs << 'Last name is required.'  if a[:last_name].to_s.strip.empty?
    begin
      d = Date.parse(a[:dob].to_s)
      errs << 'Date of birth must be in the past.' if d >= Date.today
    rescue ArgumentError
      errs << 'Date of birth is required and must be a valid date.'
    end
    errs
  end
end

# ---------- Web tier ----------
helpers do
  def h(s) = Rack::Utils.escape_html(s.to_s)
  def form_params
    { first_name: params[:first_name], last_name: params[:last_name], dob: params[:dob] }
  end
end

get('/')        { redirect '/people' }
get('/people')  { @people = People.all; erb :index }
get('/people/new') { @person = {}; @errors = []; erb :form }

post '/people' do
  @person = form_params
  @errors = People.validate(@person)
  if @errors.empty?
    People.create(@person)
    redirect '/people'
  else
    erb :form
  end
end

get '/people/:id/edit' do
  @person = People.find(params[:id]) or halt 404
  @errors = []
  erb :form
end

post '/people/:id' do
  @person = form_params.merge(id: params[:id])
  @errors = People.validate(@person)
  if @errors.empty?
    People.update(params[:id], @person)
    redirect '/people'
  else
    erb :form
  end
end

post('/people/:id/delete') { People.delete(params[:id]); redirect '/people' }

# ---------- Views ----------
__END__

@@ layout
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>People</title>
  <style>
    body { font: 15px/1.5 system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; color: #222; }
    h1 { margin-top: 0; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: .5rem .6rem; border-bottom: 1px solid #eee; }
    a.button, button { font: inherit; padding: .35rem .75rem; border: 1px solid #888; background: #f6f6f6; border-radius: 4px; cursor: pointer; text-decoration: none; color: #222; }
    a.button.primary, button.primary { background: #2d6cdf; border-color: #2d6cdf; color: #fff; }
    .errors { background: #fde8e8; border: 1px solid #f5b5b5; padding: .6rem .9rem; border-radius: 4px; }
    .field { margin: .6rem 0; display: flex; flex-direction: column; gap: .25rem; }
    input { font: inherit; padding: .35rem .5rem; border: 1px solid #aaa; border-radius: 4px; }
    .row-actions form { display: inline; }
  </style>
</head>
<body><%= yield %></body>
</html>

@@ index
<h1>People</h1>
<p><a class="button primary" href="/people/new">New person</a></p>
<table>
  <tr><th>First</th><th>Last</th><th>DOB</th><th></th></tr>
  <% @people.each do |p| %>
    <tr>
      <td><%= h p['first_name'] %></td>
      <td><%= h p['last_name'] %></td>
      <td><%= h p['dob'] %></td>
      <td class="row-actions">
        <a class="button" href="/people/<%= p['id'] %>/edit">Edit</a>
        <form method="post" action="/people/<%= p['id'] %>/delete" onsubmit="return confirm('Delete <%= h p['first_name'] %>?')">
          <button type="submit">Delete</button>
        </form>
      </td>
    </tr>
  <% end %>
</table>

@@ form
<h1><%= @person['id'] || @person[:id] ? 'Edit person' : 'New person' %></h1>
<% unless @errors.empty? %>
  <div class="errors"><ul><% @errors.each do |e| %><li><%= h e %></li><% end %></ul></div>
<% end %>
<form id="personForm" method="post"
      action="<%= (@person['id'] || @person[:id]) ? "/people/#{@person['id'] || @person[:id]}" : '/people' %>"
      novalidate>
  <div class="field">
    <label for="first_name">First name</label>
    <input id="first_name" name="first_name" value="<%= h(@person['first_name'] || @person[:first_name]) %>">
  </div>
  <div class="field">
    <label for="last_name">Last name</label>
    <input id="last_name" name="last_name" value="<%= h(@person['last_name'] || @person[:last_name]) %>">
  </div>
  <div class="field">
    <label for="dob">Date of birth</label>
    <input id="dob" name="dob" type="date" value="<%= h(@person['dob'] || @person[:dob]) %>">
  </div>
  <p>
    <button class="primary" type="submit">Save</button>
    <a class="button" href="/people">Cancel</a>
  </p>
</form>

<script>
  // Tiny client-side validation — server still validates authoritatively.
  (function () {
    var form = document.getElementById('personForm');
    form.addEventListener('submit', function (e) {
      var errs = [];
      var first = form.first_name.value.trim();
      var last  = form.last_name.value.trim();
      var dob   = form.dob.value;
      if (!first) errs.push('First name is required.');
      if (!last)  errs.push('Last name is required.');
      if (!dob)   errs.push('Date of birth is required.');
      else if (new Date(dob) >= new Date(new Date().toDateString())) {
        errs.push('Date of birth must be in the past.');
      }
      if (errs.length) {
        e.preventDefault();
        alert(errs.join('\n'));
      }
    });
  })();
</script>
