require "active_support/concern"
require "action_view"

module Sprockets::Vue
  class Script
    class << self
      include ActionView::Helpers::JavaScriptHelper

      SCRIPT_REGEX = Utils.node_regex('script')
      TEMPLATE_REGEX = Utils.node_regex('template')
      SCRIPT_COMPILES = {
        'coffee' => ->(s, input){
          CoffeeScript.compile(s, sourceMap: false, sourceFiles: [input[:source_path]], no_wrap: true)
        },
        'es6' => ->(s, input){
          {"js" => Babel::Transpiler.transform(s, sourceType: "script")["code"]}
        },
        nil => ->(s,input){ { 'js' => s } }
      }

      def call(input)
        data = input[:data]
        name = input[:name]

        input[:cache].fetch([cache_key, input[:source_path], data]) do
          script = SCRIPT_REGEX.match(data)
          template = TEMPLATE_REGEX.match(data)
          output = []

          if script
            result = SCRIPT_COMPILES[script[:lang]].call(script[:content], input)

            output << "'object' != typeof VComponents && (this.VComponents = {});
              var module = { exports: null };
              #{result['js']}; VComponents['#{name}'] = module.exports;"
          end

          if template
            output << "VComponents['#{name.sub(/\.tpl$/, "")}'].template = '#{j template[:content]}';"
          end

          output << "Vue.component('#{name.split('/').last.gsub('_', '-')}', VComponents['#{name}']);"

          { data: "#{wrap(output.join)}" }
        end
      end

      def wrap(s)
        "(function(){#{s}}).call(this);"
      end

      def cache_key
        [ self.name,
          VERSION,
        ].freeze
      end
    end
  end
end
