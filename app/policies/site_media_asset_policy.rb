# frozen_string_literal: true

class SiteMediaAssetPolicy < MediaAssetPolicy
  def index?
    user.is_owner?
  end

  undef_method(:append?)
  undef_method(:finalize?)
  undef_method(:cancel?)
end
