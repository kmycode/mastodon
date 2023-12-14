# frozen_string_literal: true

module Payloadable
  include AuthorizedFetchHelper

  # @param [ActiveModelSerializers::Model] record
  # @param [ActiveModelSerializers::Serializer] serializer
  # @param [Hash] options
  # @option options [Account] :signer
  # @option options [String] :sign_with
  # @option options [Boolean] :always_sign
  # @return [Hash]
  def serialize_payload(record, serializer, options = {})
    signer      = options.delete(:signer)
    sign_with   = options.delete(:sign_with)
    always_sign = options.delete(:always_sign)
    always_sign_unsafe = options.delete(:always_sign_unsafe)
    payload     = ActiveModelSerializers::SerializableResource.new(record, options.merge(serializer: serializer, adapter: ActivityPub::Adapter)).as_json
    object      = record.respond_to?(:virtual_object) ? record.virtual_object : record
    bearcap     = object.is_a?(String) && record.respond_to?(:type) && (record.type == 'Create' || record.type == 'Update')

    if ((object.respond_to?(:sign?) && object.sign?) && signer && (always_sign || signing_enabled?)) || bearcap || (signer && always_sign_unsafe)
      ActivityPub::LinkedDataSignature.new(payload).sign!(signer, sign_with: sign_with)
    else
      payload
    end
  end

  def signing_enabled?
    !authorized_fetch_mode?
  end
end
