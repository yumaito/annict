# frozen_string_literal: true
# == Schema Information
#
# Table name: statuses
#
#  id                   :integer          not null, primary key
#  user_id              :integer          not null
#  work_id              :integer          not null
#  kind                 :integer          not null
#  likes_count          :integer          default(0), not null
#  created_at           :datetime
#  updated_at           :datetime
#  oauth_application_id :integer
#
# Indexes
#
#  index_statuses_on_oauth_application_id  (oauth_application_id)
#  statuses_user_id_idx                    (user_id)
#  statuses_work_id_idx                    (work_id)
#

module Api
  module Internal
    class StatusesController < Api::Internal::ApplicationController
      before_action :authenticate_user!
      before_action :load_work

      def select(status_kind, page_category)
        keen_client.page_category = page_category
        ga_client.page_category = page_category
        status = StatusService.new(current_user, @work, keen_client, ga_client)
        head(200) if status.change(status_kind)
      end
    end
  end
end
