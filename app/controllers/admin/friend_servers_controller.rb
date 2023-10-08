# frozen_string_literal: true

module Admin
  class FriendServersController < BaseController
    before_action :set_friend, except: [:index, :new, :create]
    before_action :warn_signatures_not_enabled!, only: [:new, :edit, :create, :follow, :unfollow, :accept, :reject]

    def index
      authorize :friend_server, :update?
      @friends = FriendDomain.all
    end

    def new
      authorize :friend_server, :update?
      @friend = FriendDomain.new
    end

    def edit
      authorize :friend_server, :update?
    end

    def create
      authorize :friend_server, :update?

      @friend = FriendDomain.new(resource_params)

      if @friend.save
        @friend.follow!
        redirect_to admin_friend_servers_path
      else
        render action: :new
      end
    end

    def update
      authorize :friend_server, :update?

      if @friend.update(resource_params)
        redirect_to admin_friend_servers_path
      else
        render action: :edit
      end
    end

    def destroy
      authorize :friend_server, :update?
      @friend.destroy
      redirect_to admin_friend_servers_path
    end

    def follow
      authorize :friend_server, :update?
      @friend.follow!
      render action: :edit
    end

    def unfollow
      authorize :friend_server, :update?
      @friend.unfollow!
      render action: :edit
    end

    def accept
      authorize :friend_server, :update?
      @friend.accept!
      render action: :edit
    end

    def reject
      authorize :friend_server, :update?
      @friend.reject!
      render action: :edit
    end

    private

    def set_friend
      @friend = FriendDomain.find(params[:id])
    end

    def resource_params
      params.require(:friend_domain).permit(:domain, :inbox_url, :available, :pseudo_relay, :unlocked, :allow_all_posts)
    end

    def warn_signatures_not_enabled!
      flash.now[:error] = I18n.t('admin.relays.signatures_not_enabled') if authorized_fetch_mode?
    end
  end
end
