module Gnosis
  module IssuePatch
    def self.included(base)
      base.class_eval do
        has_many :pull_requests, class_name: 'PullRequest', foreign_key: 'issue_id'

        before_save :store_status_change
        after_save :log_status_change
          
        def store_status_change
          @old_status_id = status_id_was
        end

        def log_status_change
          if @old_status_id && @old_status_id != self.status_id
            old_status = IssueStatus.find_by(id: @old_status_id)
            new_status = self.status       

            Rails.logger.info "[gnosis] Triggered on: issue ##{self.id} status changed from '#{old_status&.name}' to '#{new_status.name}'"
            PullRequestService.new.create_check_run(self.id, pull_requests, new_status.name)
          end
        end

      end
    end
  end
end

unless Issue.included_modules.include? Gnosis::IssuePatch
  Issue.send(:include, Gnosis::IssuePatch)
end