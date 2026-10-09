# frozen_string_literal: true

class DomainIconMediaAssetPolicy < MediaAssetPolicy
  undef_method(:append?)
  undef_method(:finalize?)
  undef_method(:cancel?)
end
