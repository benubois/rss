module Phlex
  module Rails
    remove_const(:Streaming) if const_defined?(:Streaming)

    module Streaming
    end
  end
end