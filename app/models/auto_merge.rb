require 'sidekiq/api'

class AutoMerge < ApplicationRecord
  extend Enumerize

  enumerize :state, in: [:pending, :timeout, :success, :failure, :cancel], default: :pending

  belongs_to :user

  after_commit :delay_get_pr_details, on: [:create]

  def owner_repo
    "#{owner}/#{repo}"
  end

  def pr_url
    "https://github.com/#{owner_repo}/pull/#{pr_number}"
  end

  def pull_request
    @pull_request ||= user.client.pull_request(owner_repo, pr_number)
  end

  def pr_commit
    @pr_commit ||= user.client.combined_status(owner_repo, pull_request.head.ref)
  end

  def merge_pull_request
    user.client.merge_pull_request(owner_repo, pr_number, commit_message, { commit_title: commit_title })
  end

  def delay_get_pr_details
    delay.get_pr_details
  end

  def get_pr_details
    update(
      ref: pull_request.head.ref,
      title: pull_request.title
    )

    delay_check_pr_status
  end

  def delay_check_pr_status
    job = CheckPrStatusJob.set(wait: 2.minutes).perform_later(self)

    update(job_id: job.job_id)
  end

  def pending?
    state.pending? &&
      30.minutes.ago < pr_commit.statuses.first&.updated_at
  end

  def success?
    state.success?
  end

  def sync_with_pr_commit
    update(
      last_updated: Time.zone.now,
      state: pr_commit.state,
      statuses: pr_commit.statuses.collect(&:to_h)
    )
  end
end
