class Status < ActiveRecord::Base
  extend Enumerize

  enumerize :kind, in: { wanna_watch: 1, watching: 2, watched: 3, stop_watching: 4 }, scope: true

  belongs_to :user
  belongs_to :work

  after_create :change_latest
  after_create :save_activity
  after_create :refresh_watchers_count
  after_create :update_recommendable
  after_create :update_channel_work


  private

  def change_latest
    latest_status = user.statuses.find_by(work_id: work.id, latest: true)
    latest_status.update_column(:latest, false) if latest_status.present?

    update_column(:latest, true)
  end

  def save_activity
    Activity.create do |a|
      a.user      = user
      a.recipient = work
      a.trackable = self
      a.action    = 'statuses.create'
    end
  end

  def refresh_watchers_count
    if become_to == :watch
      work.increment!(:watchers_count)
    elsif become_to == :drop
      work.decrement!(:watchers_count)
    end
  end

  # ステータスを何から何に変えたかを返す
  def become_to
    watches  = [:wanna_watch, :watching, :watched]
    statuses = user.statuses.where(work_id: work.id).includes(:work).last(2)
    prev_status = statuses.first.kind.to_sym
    new_status  = statuses.last.kind.to_sym

    if statuses.length == 2
      return :watch if !watches.include?(prev_status) && watches.include?(new_status)
      return :drop  if watches.include?(prev_status)  && !watches.include?(new_status)
      return :keep # 見たい系 -> 見たい系 または 見るのやめた系 -> 見るのやめた系
    end

    watches.include?(new_status) ? :watch : :drop_first
  end

  # ステータスの変更があったとき、「Recommendable」の `like`, `dislike` などを呼び出して
  # オススメ作品を更新する
  def update_recommendable
    if become_to == :watch
      user.undislike(work) if user.dislikes?(work)
      user.like(work)
    elsif become_to == :drop
      user.unlike(work) if user.likes?(work)
      user.dislike(work)
    elsif become_to == :drop_first
      user.dislike(work)
    end
  end

  def update_channel_work
    case kind
    when 'wanna_watch', 'watching'
      user.create_channel_work(work)
    else
      user.delete_channel_work(work)
    end
  end
end