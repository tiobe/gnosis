class GithubAppClient
  GITHUB_API_URL = 'https://api.github.com'

  def self.client
    @client_wrapper ||= new.build_client_wrapper

    if @client_wrapper[:expires_at] <= Time.now
      @client_wrapper = new.build_client_wrapper
    end

    @client_wrapper[:client]
  end

  def build_client_wrapper
    app_client = Octokit::Client::new(
      bearer_token: jwt_token,
      api_endpoint: GITHUB_API_URL
    )

    response = app_client.create_app_installation_access_token(installation_id)

    access_token = response[:token]
    expires_at = response[:expires_at]

    {
      client: Octokit::Client.new(access_token: access_token, auto_paginate: true),
      expires_at: expires_at - 60 # refresh a minute early just in case
    }
  end

  private

  def jwt_token
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60),
      iss: ENV.fetch('GITHUB_APP_ID')
    }

    private_key = OpenSSL::PKey::RSA.new(File.read(ENV.fetch('GITHUB_PRIVATE_KEY_PATH')))
    JWT.encode(payload, private_key, 'RS256')
  end

  def installation_id
    ENV.fetch('GITHUB_INSTALLATION_ID').to_i
  end
  
end