# frozen_string_literal: true

class StatusService
  attr_writer :app

  def initialize(user, work, keen_client, ga_client)
    @user = user
    @work = work
    @keen_client = keen_client
    @ga_client = ga_client
  end

  def change(kind)
    if Status.kind.values.include?(kind)
      status = @user.statuses.new(work: @work, kind: kind, oauth_application: @app)

      if status.save
        @user.delay.update_watched_works_count
        @keen_client.app = @app
        @keen_client.statuses.create
        data_source = @app.present? ? :api : :web
        @ga_client.events.create(:statuses, :create, ds: data_source)
        return true
      end
    elsif kind == "no_select"
      latest_status = @user.latest_statuses.find_by(work: @work)
      latest_status.destroy! if latest_status.present?
      return true
    end

    false
  end
end
