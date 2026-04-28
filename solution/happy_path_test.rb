# Single happy-path Playwright test for the Sinatra Person CRUD app.
#
# Run:
#   bundle exec ruby happy_path_test.rb
#
# Deps: playwright-ruby-client, sqlite3, minitest
# Also requires the Playwright CLI on PATH (`npm i -g playwright` then
# `playwright install chromium`).
#
# The test:
#   1. Deletes people.db so the app reseeds on boot.
#   2. Boots app.rb on a free port as a child process.
#   3. Drives the UI through every corner: list, new (with both client- and
#      server-side validation), edit, delete (with confirm dialog).
#   4. After the run, asserts the DB ended in the expected state.

require 'minitest/autorun'
require 'playwright'
require 'sqlite3'
require 'socket'
require 'net/http'
require 'date'

class HappyPathTest < Minitest::Test
  APP_DIR = __dir__
  DB_PATH = File.join(APP_DIR, 'people.db')

  def setup
    File.delete(DB_PATH) if File.exist?(DB_PATH)
    @port = free_port
    @app_pid = spawn({ 'PORT' => @port.to_s }, 'ruby', 'app.rb', '-p', @port.to_s,
                     chdir: APP_DIR, out: '/tmp/app.out', err: '/tmp/app.err')
    wait_for_http("http://127.0.0.1:#{@port}/people")
  end

  def teardown
    Process.kill('TERM', @app_pid) if @app_pid
    Process.wait(@app_pid) rescue nil
  end

  def test_full_happy_path
    Playwright.create(playwright_cli_executable_path: 'playwright') do |pw|
      pw.chromium.launch(headless: false, args: ['--start-maximized']) do |browser|
        page = browser.new_page
        # Surface JS alert() text so we can assert client-side validation fired.
        alerts = []
        page.on('dialog', ->(dialog) {
          alerts << dialog.message
          dialog.accept
        })

        base = "http://127.0.0.1:#{@port}"

        # 1. Index lists the 5 seeded Flintstones.
        page.goto("#{base}/people")
        seeded = page.locator('table tr').count - 1   # minus header
        assert_equal 5, seeded, 'expected 5 seeded rows'
        assert_includes page.content, 'Fred'
        assert_includes page.content, 'Pebbles'

        # 2. New person — client-side validation: empty form.
        page.goto("#{base}/people/new")
        page.click('button.primary[type=submit]')
        assert alerts.any? { |m| m.include?('First name is required') },
               "expected client-side first-name error, got #{alerts.inspect}"
        alerts.clear

        # 3. New person — client-side validation: future DOB.
        page.fill('#first_name', 'Dino')
        page.fill('#last_name',  'Pet')
        page.fill('#dob', (Date.today + 1).strftime('%Y-%m-%d'))
        page.click('button.primary[type=submit]')
        assert alerts.any? { |m| m.include?('must be in the past') },
               "expected client-side past-date error, got #{alerts.inspect}"
        alerts.clear

        # 4. Server-side validation — bypass JS by POSTing directly.
        res = Net::HTTP.post_form(URI("#{base}/people"),
                                  'first_name' => '', 'last_name' => '',
                                  'dob' => (Date.today + 30).to_s)
        assert_equal '200', res.code
        assert_includes res.body, 'First name is required.'
        assert_includes res.body, 'Last name is required.'
        assert_includes res.body, 'must be in the past'

        # 5. Successful create.
        page.goto("#{base}/people/new")
        page.fill('#first_name', 'Dino')
        page.fill('#last_name',  'Pet')
        page.fill('#dob', '1960-09-30')
        page.click('button.primary[type=submit]')
        page.wait_for_url("#{base}/people")
        assert_includes page.content, 'Dino'
        assert_equal 6, page.locator('table tr').count - 1

        # 6. Edit Barney → Bernard.
        barney_row = page.locator('tr', hasText: 'Barney')
        barney_row.locator('a.button', hasText: 'Edit').click
        page.wait_for_selector('#first_name')
        page.fill('#first_name', 'Bernard')
        page.click('button.primary[type=submit]')
        page.wait_for_url("#{base}/people")
        assert_includes page.content, 'Bernard'
        refute_includes page.content, 'Barney'

        # 7. Delete Pebbles (the confirm dialog auto-accepts via our handler).
        pebbles_row = page.locator('tr', hasText: 'Pebbles')
        pebbles_row.locator('button', hasText: 'Delete').click
        page.wait_for_url("#{base}/people")
        refute_includes page.content, 'Pebbles'
        assert alerts.any? { |m| m.include?('Delete Pebbles?') },
               "expected delete confirm dialog, got #{alerts.inspect}"

        # 8. 404 on non-existent edit.
        res = Net::HTTP.get_response(URI("#{base}/people/9999/edit"))
        assert_equal '404', res.code

        # 9. Negative test — blank first name must not save.
        before = SQLite3::Database.new(DB_PATH).execute('SELECT COUNT(*) FROM people')[0][0]
        page.goto("#{base}/people/new")
        page.fill('#first_name', '')
        page.fill('#last_name',  'NoFirst')
        page.fill('#dob', '1960-01-01')
        # Bypass the JS guard so we exercise the server's rejection path.
        page.evaluate("document.getElementById('personForm').noValidate = true;")
        page.evaluate("document.getElementById('personForm').submit();")
        page.wait_for_selector('.errors')
        assert_includes page.content, 'First name is required.'
        after = SQLite3::Database.new(DB_PATH).execute('SELECT COUNT(*) FROM people')[0][0]
        assert_equal before, after, 'blank first name should not have created a row'
      end
    end

    # 9. DB-level assertion of final state.
    db = SQLite3::Database.new(DB_PATH)
    db.results_as_hash = true
    rows = db.execute('SELECT first_name, last_name FROM people ORDER BY id')
    names = rows.map { |r| "#{r['first_name']} #{r['last_name']}" }
    assert_equal ['Fred Flintstone', 'Wilma Flintstone', 'Bernard Rubble',
                  'Betty Rubble', 'Dino Pet'], names
  ensure
    db&.close
  end

  private

  def free_port
    s = TCPServer.new('127.0.0.1', 0)
    port = s.addr[1]
    s.close
    port
  end

  def wait_for_http(url, timeout: 15)
    deadline = Time.now + timeout
    loop do
      begin
        return if Net::HTTP.get_response(URI(url)).code.to_i < 500
      rescue Errno::ECONNREFUSED, EOFError
      end
      raise "app did not start within #{timeout}s" if Time.now > deadline
      sleep 0.2
    end
  end
end
