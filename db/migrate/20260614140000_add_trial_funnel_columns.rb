class AddTrialFunnelColumns < ActiveRecord::Migration[7.2]
  def change
    # Per-program pricing: 0 = free (Nivel 1 trial), > 0 = paid (personalized Nivel 2).
    # founder_price_clp is honored only inside the day-14 founder window (0 = none).
    add_column :programs, :price_clp, :integer, default: 0, null: false
    add_column :programs, :founder_price_clp, :integer, default: 0, null: false

    # Classifies a Webpay charge: 0 = membership (legacy door-pay), 1 = personalized
    # (Nivel 2 unlock). founder_bonus flags the expiring perk was earned at pay-time.
    add_column :payments, :purpose, :integer, default: 0, null: false
    add_column :payments, :founder_bonus, :boolean, default: false, null: false
    add_index :payments, :purpose

    # nivel2_offer_sent_at anchors the founder window (Participant#nivel2_offer_active?).
    # guarantee_claimed_at: the conditional free-extra-cycle guarantee (null = unclaimed).
    add_column :participants, :nivel2_offer_sent_at, :datetime
    add_column :participants, :guarantee_claimed_at, :datetime
  end
end
