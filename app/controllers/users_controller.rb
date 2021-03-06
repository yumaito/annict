# frozen_string_literal: true
# == Schema Information
#
# Table name: users
#
#  id                   :integer          not null, primary key
#  username             :string(510)      not null
#  email                :string(510)      not null
#  role                 :integer          not null
#  encrypted_password   :string(510)      default(""), not null
#  remember_created_at  :datetime
#  sign_in_count        :integer          default(0), not null
#  current_sign_in_at   :datetime
#  last_sign_in_at      :datetime
#  current_sign_in_ip   :string(510)
#  last_sign_in_ip      :string(510)
#  confirmation_token   :string(510)
#  confirmed_at         :datetime
#  confirmation_sent_at :datetime
#  unconfirmed_email    :string(510)
#  checkins_count       :integer          default(0), not null
#  notifications_count  :integer          default(0), not null
#  created_at           :datetime
#  updated_at           :datetime
#
# Indexes
#
#  users_confirmation_token_key  (confirmation_token) UNIQUE
#  users_email_key               (email) UNIQUE
#  users_username_key            (username) UNIQUE
#

class UsersController < ApplicationController
  before_action :load_i18n, only: %i(show following followers)
  before_action :authenticate_user!, only: %i(destroy share)
  before_action :set_user, only: %i(show works following followers)

  def show
    @watching_works = @user.works.watching.published
    checkedin_works = @watching_works.checkedin_by(@user).order("c2.checkin_id DESC")
    other_works = @watching_works.where.not(id: checkedin_works.pluck(:id))
    @works = (checkedin_works + other_works).first(9)
    @favorite_characters = @user.favorite_characters.order(id: :desc)
    @favorite_casts = @user.favorite_people.with_cast.order(id: :desc)
    @favorite_staffs = @user.favorite_people.with_staff.order(id: :desc)
    @favorite_organizations = @user.favorite_organizations.order(id: :desc)

    activities = @user.
      activities.
      order(id: :desc).
      includes(:recipient, trackable: :user, user: :profile).
      page(1)
    page_object = render_jb("api/internal/activities/index",
      user: user_signed_in? ? current_user : nil,
      activities: activities)
    gon.push(pageObject: page_object)
  end

  def works(status_kind, page: nil)
    @works = @user.works.on(status_kind).published
    @seasons = Season.
      where(id: @works.pluck(:season_id)).
      order(sort_number: :desc).
      page(page).
      per(10)
  end

  def following
    @users = @user.followings.order("follows.id DESC")
  end

  def followers
    @users = @user.followers.order("follows.id DESC")
  end

  def destroy
    sayonara = SayonaraService.new(current_user)
    sayonara.bye_bye!
    redirect_to root_path, notice: "退会しました。(´・ω;:.."
  end

  private

  def set_user
    @user = User.find_by!(username: params[:username])
  end

  def load_i18n
    keys = {
      "verb.follow": nil,
      "noun.following": nil,
      "messages._common.are_you_sure": nil,
      "messages.components.mute_user_button.the_user_has_been_muted": nil
    }

    load_i18n_into_gon keys
  end
end
