# frozen_string_literal: true
require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @notifications_request = stub_notifications_request(body: '[]') }

  test 'GET #new redirects to /auth/github' do
    get '/login'
    assert_redirected_to '/auth/github'
  end

  test 'POST #create finds the GitHub user from the hash and redirects to the root_path' do
    OmniAuth.config.mock_auth[:github].uid = users(:andrew).github_id
    post '/auth/github/callback'

    assert_redirected_to root_path
  end

  test 'POST #create creates a GitHub user from the hash and redirects to the root_path' do
    post '/auth/github/callback'

    assert User.find_by(github_id: OmniAuth.config.mock_auth[:github].uid)
    assert_redirected_to root_path
  end

  test 'POST #create forces the user to sync their notifications' do
    OmniAuth.config.mock_auth[:github].uid = users(:andrew).github_id

    post '/auth/github/callback'
    assert_requested @notifications_request, times: 2
  end

  test 'POST #create redirects to the root_path with an error message if they are not an org member' do
    user = users(:andrew)
    OmniAuth.config.mock_auth[:github].uid           = user.github_id
    OmniAuth.config.mock_auth[:github].info.nickname = user.github_login

    stub_restricted_access_enabled
    stub_env('GITHUB_ORGANIZATION_ID', value: 1)
    stub_organization_membership_request(organization_id: 1, login: user.github_login, successful: false)

    post '/auth/github/callback'
    assert_redirected_to root_path
    assert_equal 'Access denied.', flash[:error]
  end

  test 'POST #create redirects to the root_path with an error message if they are not an team member' do
    user = users(:andrew)
    OmniAuth.config.mock_auth[:github].uid           = user.github_id
    OmniAuth.config.mock_auth[:github].info.nickname = user.github_login

    stub_restricted_access_enabled
    stub_env('GITHUB_TEAM_ID', value: 1)
    stub_team_membership_request(team_id: 1, login: user.github_login, successful: false)

    post '/auth/github/callback'
    assert_redirected_to root_path
    assert_equal 'Access denied.', flash[:error]
  end

  test 'POST #create is successful if the user is an org member' do
    user = users(:andrew)
    OmniAuth.config.mock_auth[:github].uid           = user.github_id
    OmniAuth.config.mock_auth[:github].info.nickname = user.github_login

    stub_restricted_access_enabled
    stub_env('GITHUB_ORGANIZATION_ID', value: 1)
    stub_organization_membership_request(organization_id: 1, login: user.github_login, successful: true)

    post '/auth/github/callback'
    assert_redirected_to root_path
    assert_nil flash[:error]
  end

  test 'POST #create is successful if the user is a team member' do
    user = users(:andrew)
    OmniAuth.config.mock_auth[:github].uid           = user.github_id
    OmniAuth.config.mock_auth[:github].info.nickname = user.github_login

    stub_restricted_access_enabled
    stub_env('GITHUB_TEAM_ID', value: 1)
    stub_team_membership_request(team_id: 1, login: user.github_login, successful: true)

    post '/auth/github/callback'
    assert_redirected_to root_path
    assert_nil flash[:error]
  end

  test 'GET #destroy redirects to /' do
    get '/logout'
    assert_redirected_to '/'
  end

  test 'GET #failure redirects to / and sets a flash message' do
    get '/auth/failure'

    assert_redirected_to '/'
    assert_equal 'There was a problem authenticating with GitHub, please try again.', flash[:error]
  end
end
