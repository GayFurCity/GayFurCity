# frozen_string_literal: true

module Sources
  module Alternates
    module Helper
      def alternate_should_work(url, alternate_class, replacement_url)
        should("be handled by the correct strategy") do
          site = ::Sources::Alternates.find(url)

          assert_instance_of(alternate_class, site)
        end

        should("result in the correct URL") do
          site = ::Sources::Alternates.find(url)

          assert_equal(replacement_url, site.original_url)
        end
      end
    end
  end
end
