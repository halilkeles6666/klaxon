class AddTelegramChatIdToUsers < ActiveRecord::Migration[8.0]
  def change
    # Where this user receives on-call pages over Telegram (their chat id with
    # the bot). Blank -> no direct Telegram alert (a global default may apply).
    add_column :users, :telegram_chat_id, :string
  end
end
