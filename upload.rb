require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'
require 'logger'
require 'pp'
require File.join(File.dirname(__FILE__), '.', 'cmdlinetool')

include Helpers

API_VERSION = 'v2'
CACHED_API_FILE = "drive-#{API_VERSION}.cache"
CREDENTIAL_STORE_FILE = "drive-oauth2.json"
OAUTH_SCOPE = 'https://www.googleapis.com/auth/drive'
REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'
SNAPSHOTS_FOLDER_ID = "0BxW5m4Ezq-HEYjNNQ0h3NnhmV1E"

# OPTIONS = [
#   optdef(:id, ["-i", "--clientid"], "Google Drive API Client ID",  true),
#   optdef(:secret, ["-s", "--clientsecret"], "Google Drive API Client Secret", true),
#   optdef(:code, ["-c", "--authorizationcode"], "Google Drive API Authorization Code", true)
# ]

def setup_drive
  log_file = File.open('drive.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG

  # Create a new API client & load the Google Drive API
  client = Google::APIClient.new(
    :application_name => 'CoverHound Performance Snapshots Manager',
    :application_version => '1.0.0'
  )

  # FileStorage stores auth credentials in a file, so they survive multiple runs
  # of the application. This avoids prompting the user for authorization every
  # time the access token expires, by remembering the refresh token.
  # Note: FileStorage is not suitable for multi-user applications.
  file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
  if file_storage.authorization.nil?
    client_secrets = Google::APIClient::ClientSecrets.load
    # The InstalledAppFlow is a helper class to handle the OAuth 2.0 installed
    # application flow, which ties in with FileStorage to store credentials
    # between runs.
    flow = Google::APIClient::InstalledAppFlow.new(
      :client_id => client_secrets.client_id,
      :client_secret => client_secrets.client_secret,
      :scope => [OAUTH_SCOPE]
    )
    client.authorization = flow.authorize(file_storage)
  else
    client.authorization = file_storage.authorization
  end

  drive = nil
  # Load cached discovered API, if it exists. This prevents retrieving the
  # discovery document on every run, saving a round-trip to API servers.
  if File.exists? CACHED_API_FILE
    File.open(CACHED_API_FILE) do |file|
      drive = Marshal.load(file)
    end
  else
    drive = client.discovered_api('drive', API_VERSION)
    File.open(CACHED_API_FILE, 'w') do |file|
      Marshal.dump(drive, file)
    end
  end

  return client, drive
end

# Handles files.insert call to Drive API.
def upload_file(client, drive, filename)
  # Insert a file
  file = drive.files.insert.request_schema.new({
    'title' => 'report.json',
    'description' => 'Performance snapshot',
    'mimeType' => 'application/json',
    'parents' => [{
      "kind" => "drive#fileLink",
      "id" => SNAPSHOTS_FOLDER_ID
    }]
  })

  media = Google::APIClient::UploadIO.new(filename, 'application/json')
  result = client.execute(
    :api_method => drive.files.insert,
    :body_object => file,
    :media => media,
    :parameters => {
      'uploadType' => 'multipart',
      'alt' => 'json'
    }
  )

  # Pretty print the API result
  jj result.data.to_hash
end

##
# Retrieve a list of File resources.
#
# @param [Google::APIClient] client
#   Authorized client instance
# @return [Array]
#   List of File resources.
#
def retrieve_all_files(client, drive)
  result = Array.new
  page_token = nil
  begin
    parameters = {}
    if page_token.to_s != ''
      parameters['pageToken'] = page_token
    end
    api_result = client.execute(
      :api_method => drive.files.list,
      :parameters => parameters)
    if api_result.status == 200
      pp api_result.inspect
      files = api_result.data
      result.concat(files.items)
      page_token = files.next_page_token
    else
      puts "An error occurred: #{result.data['error']['message']}"
      page_token = nil
    end
  end while page_token.to_s != ''
  result
end

def run
  tty = CmdLineTool.new
  tty.has_an_arg!

  filename = tty.input

  client, drive = setup_drive()
  #retrieve_all_files(client, drive)
  upload_file(client, drive, filename)
end

run
