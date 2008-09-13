# AclSystem2Ownership

module Ocher
  module AccessControlOwnership

    def self.included(subject)
      subject.extend(ClassMethods)
    end

    class OwnerHandler < Caboose::AccessHandler
      def check(key, context)
        if key.downcase == 'owner'
          logged_user context[:user] do
            unless context[:owner].is_a?(Array)
              (context[:user].id == context[:owner].id)
            else
              context[:owner].each do |owner|
                return true if owner.id == context[:user].id
              end
              false
            end
          end
        elsif key.downcase == 'page_owner'
          logged_user context[:user] do
            (context[:user].id == context[:page_owner].id)
          end
        else
          logged_user context[:user] do
            context[:user].roles.map{ |role| role.title.downcase}.include?(key.downcase)
          end
        end
      end

      protected

      def logged_user user
        if user != nil
          yield
        else
          false
        end
      end

    end

    module ClassMethods
      def owner(eval_owner, options = {}, action_owners = {})
        class << action_owners
          def to_conditions(owner)    # method that creates if-elsif-else string using hash data
            return '' if self.size == 0
            result = ''
            first = true
            self.each do |k, v|
              v = "current_user" if v.nil?    # insert only '' if v == nil
              if first
                result << "if action_name == '#{k}' then @default_access_context[:owner] = #{v}\n"
                first = false
              else
                result << "elsif action_name == '#{k}' then @default_access_context[:owner] = #{v}\n"
              end
            end
            result << "else\n@default_access_context[:owner] = #{owner}\n"
            result << 'end'
            result
          end
        end

        module_eval <<-EOS
          def default_access_context
            @default_access_context ||= {}
            @default_access_context[:user] = send(:current_user) if respond_to?(:current_user)
            @default_access_context[:page_owner] = #{options[:page_owner] || 'nil'}
            if action_owners.nil? || action_owners.empty?
              @default_access_context[:owner] = #{eval_owner}
            else
              #{action_owners.to_conditions(eval_owner)}
            end
            @default_access_context
          end
        EOS

        define_method(:action_owners) do
          action_owners
        end

        define_method(:retrieve_access_handler) do
          OwnerHandler.new
        end
      end
    end # ClassMethods
  end
end
