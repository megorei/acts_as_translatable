class ActiveRecord::Base
  def self.acts_as_translatable_on(*fields)
    eval "class ::#{name}
            after_save :save_translations
            after_destroy :destroy_record_translations
            
            def translations
              unless @translations
                @translations = {}
                I18n.available_locales.each do |locale|
                  @translations[locale] ||= {}
                end
                record_translations.each do |translation|
                  @translations[translation.locale.to_sym] ||= {}
                  @translations[translation.locale.to_sym][translation.translatable_field.to_sym] = translation.content
                end
              end
              @translations
            end

            def record_translations
              @record_translations ||= RecordTranslation.where(:translatable_id => id, :translatable_type => self.class.name)
            end
          
            def save_translations
              # delete all previous translations of this record
              destroy_record_translations
              
              # loop through updated translations
              translations.each_pair do |locale, fields|
                fields.each_pair do |field, content|
                  # create translation record
                  RecordTranslation.create :translatable_id => id, :translatable_type => self.class.name, :translatable_field => field, :locale => locale.to_s, :content => content unless content.blank?
                end
              end
            end
            
            def destroy_record_translations
              # delete all translations of this record
              record_translations.destroy_all
            end
          end"
    
    localized_fields = ""
    I18n.available_locales.each do |locale|
      fields.each do |field|
        localized_fields << "def #{field}_#{locale}
                               get_field_content(\"#{locale}\".to_sym, \"#{field}\".to_sym)
                             end
                             def #{field}_#{locale}=(content)
                               set_field_content(\"#{locale}\".to_sym, \"#{field}\".to_sym, content)
                             end
                             "
      end
    end
    
    fields.each do |field|
      eval "class ::#{name}
              def #{field}
                get_field_content(I18n.locale, \"#{field}\")
              end

              def #{field}?
                !#{field}.blank?
              end

              def #{field}=(content)
                set_field_content(I18n.locale, \"#{field}\", content)
              end
              
              #{localized_fields}
              
              def get_field_content(locale, field)
                # get I18n fallbacks
                if I18n.respond_to?(:fallbacks)
                  locales = I18n.fallbacks[locale.to_sym]
                else
                  locales = [locale.to_sym]
                end
                
                # fallbacks
                locales.each do |l|
                  content = translations[l][field.to_sym]
                  return content if content
                end
                
                # none found
                return nil
              end
              
              def set_field_content(locale, field, content)
                translations[locale.to_sym][field.to_sym] = content
              end
            end"  
    end
  end
end

