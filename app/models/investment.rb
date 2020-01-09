require "roo"
require "set"

# ================================================
# RUBY->MODEL->INVESTMENT ========================
# ================================================

# t.integer "user_id"
# t.integer "deal_id", null: false
# t.integer "amount_invested"
# t.date "invested_on"
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false
# t.string "investing_entity"
# t.string "investor_email"
# t.string "investor_first_name"
# t.string "investor_last_name"
# t.integer "amount_cents"
# t.string "amount_currency", default: "USD", null: false
# t.string "investor_entity"
# t.string "gross_distribution"


class Investment < ActiveRecord::Base
  belongs_to :investor, class_name: 'User', foreign_key: :user_id, inverse_of: :investments
  belongs_to :deal, inverse_of: :investors

  validates_presence_of :deal

  default_scope { order(invested_on: :desc) }

  scope :active, -> { joins(:deal).where('deals.closed_at IS NULL') }
  scope :closed, -> { joins(:deal).where('deals.closed_at IS NOT NULL') }

  monetize :amount_cents, allow_nil: true

  def name
    [investor&.name, deal&.title].compact.join(" - ")
  end

  def display_date
    deal&.date&.strftime("%m/%d/%y") || "n/a"
  end

  def forms
    deal.forms.to_a + deal.property&.forms.to_a
  end

  def self.import(property_id, file, mapping)
    puts "import data from file #{file}"
    # create_deals(file, property_id)
    # create_investments(file)
    CSV.foreach(file, headers: true) do |row|
      deal = Deal.find_or_create_by(title: row[mapping["investing_entity"]])
      deal.update(property_id: property_id)

      investor_hash = {
        deal_id: deal.id,
        investor_last_name: row[mapping["investor_last_name"]],
        investor_first_name: row[mapping["investor_first_name"]],
        investor_email: row[mapping["investor_email"]],
        investing_entity: row[mapping["investing_entity"]],
        investor_entity: row[mapping["investor_entity"]],
        gross_distribution_percentage: row[mapping["gross_distribution_percentage"]],
        amount_invested: row[mapping["amount_invested"]],
        user_id: get_user(row, mapping)
      }
      puts investor_hash
      Investment.create! investor_hash
    end
  rescue => e
    puts e.backtrace.join("\n")
    puts e
    # end
  end

  def calc_gross_distribution
    deal.property.gross_distributions.to_i * gross_distribution_percentage.to_f.round(4)
  rescue => e  
    return  "N/A"
  end

  def gross_distribution_view
    "#{(gross_distribution_percentage.to_f * 100).round(4) }%"
  end

  private

  def self.create_deals(file, property_id)
    
    puts "create Deals from file #{file}"
    deals = Set.new

    xlsx = Roo::Spreadsheet.open(file)
    xlsx.each_row_streaming(offset: 1) do |row|
      title = sanitized_string_from(row[0])
      next if title.blank?
      
      deals << title
      print "."
    end

    # values = deals.to_a.map { |title| "('#{title}', '#{Time.now}', '#{Time.now}', #{property_id})" }.join(",")
    # ActiveRecord::Base.connection.execute("INSERT INTO deals (title, created_at, updated_at, property_id) VALUES #{values}")
    deals.each do |deal|
      Deal.where(title: deal, property_id: property_id).first_or_create
    end
    Deal.pluck(:id, :title).map { |d| @deals[d[1]] = d[0] } 
  end

  def self.sanitized_int_from(key)
    key&.value || 0
  end

  def self.sanitized_string_from(key)
    (key&.value || "").to_s.strip.gsub("'", %q(\\\'))
  end

  def self.get_user(row, mapping)
    first_name = row[mapping["investor_first_name"]]&.strip
    last_name = row[mapping["investor_last_name"]]&.strip
    email = row[mapping["investor_email"]]&.strip ? row[mapping["investor_email"]]&.strip : "#{first_name}_#{last_name}#{rand(1000)}@syndicatedequities.com"
    user = User.find_by(email: email&.downcase)
    p user
    if !user
      user = User.create(
        email: email, 
        password: "Se1#{SecureRandom.base64(8)}",
        first_name: first_name,
        last_name: last_name
      )
    end

    user
  rescue => e  
    puts "[get_user]ERROR for #{email}: #{e}"
  end

  def self.create_temp_csv(file)
    FileUtils.cp(file, "lib/imports")
  end

  def self.total_gross_distribution(gross_distributions)
    total = 0
    gross_distributions.each do |gross|
      total += gross.to_i
    end
    total
  end
end
