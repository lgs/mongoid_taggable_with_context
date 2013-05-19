module Mongoid::TaggableWithContext::GroupBy
  module TaggableWithContext
    extend ActiveSupport::Concern
    included do
      raise <<-ERR
        Mongoid::TaggableWithContext::GroupBy::TaggableWithContext is no longer used.
        Instead, please include both Mongoid::TaggableWithContext and
        Mongoid::TaggableWithContext::AggregationStrategy::RealTimeGroupBy
        in your Model.
      ERR
    end
  end
  module AggregationStrategy
    module RealTime
      extend ActiveSupport::Concern
      included do
        raise <<-ERR
          Mongoid::TaggableWithContext::GroupBy::AggregationStrategy::RealTime
          is no longer used. Instead, please include both Mongoid::TaggableWithContext and
          Mongoid::TaggableWithContext::AggregationStrategy::RealTimeGroupBy
          in your Model.
        ERR
      end
    end
  end
end