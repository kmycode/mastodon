# frozen_string_literal: true

class ActivityPub::ActivityPresenter < ActiveModelSerializers::Model
  attributes :id, :type, :actor, :published, :to, :cc, :virtual_object

  class << self
    def from_status(status, use_bearcap: true, allow_inlining: true, for_misskey: false, for_friend: false)
      new.tap do |presenter|
        presenter.id        = ActivityPub::TagManager.instance.activity_uri_for(status)
        presenter.type      = status.reblog? ? 'Announce' : 'Create'
        presenter.actor     = ActivityPub::TagManager.instance.uri_for(status.account)
        presenter.published = status.created_at
        presenter.to        = for_friend ? ActivityPub::TagManager.instance.to_for_friend(status) : ActivityPub::TagManager.instance.to(status)
        presenter.cc        = for_misskey ? ActivityPub::TagManager.instance.cc_for_misskey(status) : ActivityPub::TagManager.instance.cc(status)

        presenter.virtual_object = begin
          if status.reblog?
            if allow_inlining && status.account == status.proper.account && status.proper.private_visibility? && status.local?
              status.proper
            else
              ActivityPub::TagManager.instance.uri_for(status.proper)
            end
          elsif status.limited_visibility? && use_bearcap
            "bear:?#{{ u: ActivityPub::TagManager.instance.uri_for(status.proper), t: status.capability_tokens.first.token }.to_query}"
          else
            status.proper
          end
        end
      end
    end

    def from_encrypted_message(encrypted_message)
      new.tap do |presenter|
        presenter.id = ActivityPub::TagManager.instance.generate_uri_for(nil)
        presenter.type = 'Create'
        presenter.actor = ActivityPub::TagManager.instance.uri_for(encrypted_message.source_account)
        presenter.published = Time.now.utc
        presenter.to = ActivityPub::TagManager.instance.uri_for(encrypted_message.target_account)
        presenter.virtual_object = encrypted_message
      end
    end
  end
end
