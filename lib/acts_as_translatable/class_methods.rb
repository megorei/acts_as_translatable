module ActsAsTranslatable
  module ClassMethods
    def acts_as_translatable_on(*fields)
      after_initialize :translations
      accepts_nested_attributes_for :record_translations

      if ::ActiveRecord::VERSION::MAJOR < 4  
        has_many :record_translations, :foreign_key => :translatable_id, :conditions => { :translatable_type => name}, :dependent => :destroy
        default_scope :include => :record_translations
      else     
        has_many :record_translations, lambda { where :translatable_type => name }, :foreign_key => :translatable_id, :dependent => :destroy
        default_scope { includes :record_translations }
      end

      # loop through fields to define methods such as "name" and "description"
      fields.each do |field|
        define_method "#{field}" do
          get_field_content(I18n.locale, field)
        end

        define_method "#{field}?" do
          !send("#{field}").blank?
        end

        define_method "#{field}=" do |content|
          set_field_content(I18n.locale, field, content)
        end

        # loop through fields to define methods such as "name_en" and "name_es"
        I18n.available_locales.each do |locale|
          define_method "#{field}_#{locale}" do
            get_field_content(locale, field)
          end

          define_method "#{field}_#{locale}?" do
            !send("#{field}_#{locale}").blank?
          end

          define_method "#{field}_#{locale}=" do |content|
            set_field_content(locale, field, content)
          end
        end
      end

      define_method :translations do
        # load translations
        unless @translations
          @translations = {}
          I18n.available_locales.each do |locale|
            @translations[locale] ||= []
          end
          record_translations.each do |translation|
            @translations[translation.locale.to_sym] ||= []
            @translations[translation.locale.to_sym] << translation
          end
        end
        @translations
      end

      define_method :get_field_content do |locale, field|
        # get I18n fallbacks
        if self.class.enable_locale_fallbacks && I18n.respond_to?(:fallbacks)
          locales = I18n.fallbacks[locale]
        else
          locales = [locale]
        end

        # content default
        content = nil
        locales.each do |l|
          if (t = translations[l.to_sym].to_a.find{|t| t.translatable_field.to_s == field.to_s }).present?
            content = t.content
            break
          end
        end

        # return content
        content
      end

      define_method :set_field_content do |locale, field, content|
        # set field content
        if (t = translations[locale.to_sym].to_a.find{|t| t.translatable_field.to_s == field.to_s }).present?
          t.content = content
        else
          translations[locale.to_sym] << self.record_translations.build(
            :translatable_field => field,
            :locale             => locale.to_sym,
            :content            => content
          )
        end
      end
    end

    def enable_locale_fallbacks
      unless @enable_locale_fallbacks_set
        @enable_locale_fallbacks = true
        @enable_locale_fallbacks_set = true
      end
      @enable_locale_fallbacks
    end

    def enable_locale_fallbacks=(enabled)
      @enable_locale_fallbacks = enabled
      @enable_locale_fallbacks_set = true
    end
  end
end