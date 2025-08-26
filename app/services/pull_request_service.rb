# frozen_string_literal: true

class PullRequestService
  def sync
    fetch_repositories.each do |repository|
      fetch_repository_pull_requests(repository).each do |pull_request|
        Rails.logger.info "Processing pull request #{pull_request[:html_url]}"

        pull_request_hash = pull_request.to_h
        pull_request_hash[:merged] = pull_request[:merged_at].present?

        WebhookHandler.new.handle_github(pull_request: pull_request_hash)
      end
    end
  end

  def client
    @client = GithubAppClient.client
  end

  def fetch_repositories
    client.org_repositories(ENV.fetch('GITHUB_ORGANIZATION_NAME'), type: :all)
  end

  def fetch_repository_pull_requests(repository)
    client.pull_requests(repository[:full_name], state: :all)
  end

  def create_check_run(id, pull_requests, status)
    pull_requests.each do |pr|
      Rails.logger.info "[gnosis] Updating PR ##{pr.id} | Title: #{pr.title} | URL: #{pr.url} | State: #{pr.state}"

      # Only update if the pull request hasn't been merged
      if pr.was_merged == false
        begin
          client.create_check_run(
            pr.repo,
            "Redmine Issue Status",
            pr.head_sha,
            {
              **parse_checkrun_status(status),
              output: {
                title: "RM-#{id}: #{status}",
                summary: "Status: #{status}"
              },
              details_url: "https://redmine.tiobe.com/issues/#{id}",
            }
          )
        rescue Octokit::Error => e
          Rails.logger.warn "[gnosis] Failed to create check run for PR ##{pr.id} (repo: #{pr.repo}) - #{e.class}: #{e.message}"
        rescue StandardError => e
          Rails.logger.error "[gnosis] Unexpected error when creating check run for PR ##{pr.id} - #{e.class}: #{e.message}"
        end
      end
    end
  end

  private

  def parse_checkrun_status(status)
    case status
    when 'Verified', 'Closed'
      { status: 'completed', conclusion: 'success' }
    when 'Rejected'
      { status: 'completed', conclusion: 'failure' }
    when 'Testing'
      { status: 'in_progress' }
    else
      { status: 'queued' }
    end
  end

end
