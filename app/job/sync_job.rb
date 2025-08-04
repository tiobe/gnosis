# frozen_string_literal: true

class SyncJob < ActiveJob::Base
  def perform
    info('Starting with pull request sync')
    PullRequestService.new.sync
    info('End pull request sync')
  end

  private

  def info(msg)
    Rails.logger.info("[PullRequestSyncJob] --- #{msg}")
  end
end
