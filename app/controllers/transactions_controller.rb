class TransactionsController < ApplicationController
	protect_from_forgery except: [:hook]
	before_action :signed_in_user #, only: [:new, :edit, :update, :delete, :stripe, :stripe_success, :accept, :purchase_order]
	before_action :transaction_exists?, only: [:new, :stripe]
	before_action :transaction_owner?, only: [:accept]

	def new
		@transaction = Transaction.new
		@item = Item.find(params[:item_id])

    @prices = @item.prices
    @pictures = Picture.where(item_id: @item.id)

    @type_dropdown = []

    @prices.each do |price|
    	@type_dropdown.push([price.timeframe])
    end

		@shared = !(Share.where(user_id: current_user.id, item_id: @item.id).empty?) && !(Share.where(user_id: current_user.id, item_id: @item.id).first.discount_used)
	end

	def stripe
		Stripe.api_key = Rails.configuration.stripe[:secret_key]

		item = Item.where(id: params[:item_id]).first

		if !item.nil? && Transaction.where("(transactions.item_id = #{item.id} AND \
			transactions.buyer_id = #{current_user.id} AND \
			(transactions.status = ' Request Pending' OR transactions.status = 'Accepted' OR \
			transactions.status = 'In Progress'))").empty?

			if current_user.stripe_customer_id.nil?
				@customer = Stripe::Customer.create(
					:email => params[:stripeEmail],
					:source => params[:stripeToken]
				)
				current_user.stripe_customer_id = @customer.id
				current_user.save
			end

			seller = User.where(id: item.user_id).first

			order_transaction = Transaction.new(item_id: item.id, buyer_id: current_user.id,
			seller_id: item.user_id, total_price: params[:price], length: item.listing_type == 'sell' ? nil : params[:duration])

			if item.listing_type == "lease"
				order_transaction.addons = params[:addon]
			end

			order_transaction.save

			if Conversation.between(current_user.id, seller.id).present?
				@conversation = Conversation.between(current_user.id,
				seller.id).first
			else
				@conversation = Conversation.create!(sender_id: current_user.id, recipient_id: seller.id)
			end

			RequestSentEmailJob.set(wait: 1.seconds).perform_later(order_transaction)

			redirect_to conversation_messages_path(@conversation, item_id: item.id)

		else
			redirect_to item_path(item.id)
		end
	end

	def destroy
		@transaction = Transaction.find(params[:id])
		@transaction.status = "Denied"
		@transaction.save

		@conversation = Conversation.between(@transaction.seller_id, @transaction.buyer_id).first
		@buyer = User.find(@transaction.buyer_id)
		@seller = User.find(@transaction.seller_id)
		@item = Item.find_by(id: @transaction.item_id)
		@message = @conversation.messages.new(user_id: @buyer.id)
		@message2 = @conversation.messages.new(user_id: @seller.id)
		@message.body = "AdaeBot: #{@buyer.name}, your request for #{@item.title} has been denied, but don't worry you can keep browsing!"
		@message2.body = "AdaeBot: #{@seller.name}, you have denied the request for #{@item.title}. Feel free to keep browsing!"
		@message.save
		@message2.save
		ContactMailer.adaebot_message(@buyer, @message).deliver_now
		ContactMailer.adaebot_message(@seller, @message2).deliver_now

		redirect_to conversations_path
	end

	def cancel
		redirect_to conversations_path
	end

	def accept
		transaction_hash = charge_stripe

		transaction = transaction_hash["transaction"]

		transaction.status = "Accepted"
		transaction.save

		if(Item.find(transaction.item_id).listing_type == "sell")
			cancel_transactions = Transaction.where("(transactions.status = 'Pending') AND \
			(transactions.item_id = #{transaction.item_id}) AND \
			(transactions.buyer_id != #{transaction.buyer_id})")

			cancel_transactions.each do |t|
				t.status = "Denied"
				t.save
			end
		end

		@conversation = Conversation.between(transaction.seller_id,transaction.buyer_id).first
		@buyer = User.find(transaction.buyer_id)
		@seller = User.find(transaction.seller_id)
		@item = Item.find_by(id: transaction.item_id)
		@message = @conversation.messages.new(user_id: @buyer.id)
		@message2 = @conversation.messages.new(user_id: @seller.id)
		@message.body = "AdaeBot: #{@buyer.name}, your request for #{@item.title} has been accepted by #{@seller.name}."
		@message2.body = "AdaeBot: #{@seller.name}, you have accepted a request from #{@buyer.name} for #{@item.title}."
		@message.save
		@message2.save
		ContactMailer.adaebot_message(@buyer, @message).deliver_now
		ContactMailer.adaebot_message(@seller, @message2).deliver_now
		redirect_to :back
	end

	# Grabs all the necessary data and presents an invoice display page after purchases
	def stripe_success
		@order = Transaction.find(params[:id])
		@item = Item.where(id: @order.id).first
		@total_amount = ((@order.total_price - 0.3) / 1.029)
		@adae_fee = @order.total_price - @total_amount
		@length = @order.length.split('-')[1]
		@length = @length[0..@length.length - 2]
		@price = @item.prices.where(timeframe: @length).first

		# Only the purchaser can see this information
		if current_user.id == @order.buyer_id
=begin
			@contact = current_user

			invoice_details_hash = { order: @order,
				purchase_items: @purchase_items,
				notification_params: @notification_params_name,
				currency: "cad",
				billed_contact: @contact,
				adae_fee: @adae_fee
			}
=end

			# InvoiceMailer.invoice_details(invoice_details_hash).deliver_now
			# respond_to do |format|
			# 	format.html
			# 	format.pdf do
			# 		render pdf: "Invoice ##{@order.id}",
			# 			template: "transactions/purchase_order.pdf.erb"
			# 	end
			# end
		else
			redirect_to root_path, flash: {warning: "You are not authorized to view this page."}
		end
	end

	# For sidebar use, to list all the personal purchases made by user
	def list_personal_purchases
		@purchases = Transaction.where(buyer_id:current_user.id).to_a
	end

	def purchase_order
		@order = Transaction.find_by(id:params[:id])
		# Only the purchaser can see this information
		if current_user.id == @order.buyer_id
			@purchase_items = Transaction.where(transaction_id: @order[:id])
			@notification_params_name = JSON.parse(@order.StripeTransaction.all[0][:notification_params])["source"]["name"]
			@contact = current_user
			respond_to do |format|
				format.html
				format.pdf do
					render pdf: "Invoice ##{@order.id}",
						template: "transactions/purchase_order.pdf.erb"
				end
			end
		else
			redirect_to root_path, flash: {warning: "You are not authorized to view this page."}
		end
	end

	private

		def charge_stripe
			transaction = Transaction.find(params[:transaction])
			item = Item.find(params[:item_id])
			seller = User.find(transaction.seller_id)
			buyer = User.find(transaction.buyer_id)

			description = "#{seller.name}(#{seller.id}), #{item.listing_type}s, to #{buyer.name}(#{buyer.id})"

			@customer = Stripe::Customer.retrieve(buyer.stripe_customer_id)

			charge_price = transaction.total_price.to_f

			if !(Share.where(user_id: current_user.id, item_id: item.id).empty?) && !(Share.where(user_id: current_user.id, item_id: item.id).first.discount_used)
				shared = Share.where(user_id: current_user.id, item_id: item.id).first
				charge_price = charge_price * 0.95
				shared.discount_used = true
				shared.save
			end

			#If the Buyer has a balance, subtract the balance from the total before charge.
			if buyer.balance > 0
				if buyer.balance > charge_price
					balance_used = charge_price
					buyer.balance = buyer.balance - charge_price
					charge_price = 0
					buyer.save
				else
					balance_used = buyer.balance - charge_price
					charge_price = charge_price - buyer.balance
					buyer.balance = 0
					buyer.save
				end
			end

			if charge_price > 0
				# Charge the customer instead of the card
				begin
					charge = Stripe::Charge.create(
						:customer => @customer.id,
				    :amount => charge_price.to_i, # amount in cents, again
				    :currency => "cad",
				    :description => description
				  )

					rescue Stripe::CardError => e
						flash[:alert] = e.message
						redirect_to conversations_path
						#return false
				end

				if charge[:paid]
					stripeCharge = {
						txn_type: charge[:object],
						currency: charge[:currency],
						total_amount: charge[:amount],
						notification_params: charge,
						txn_id: charge[:id],
						status: charge[:paid],
						description: charge[:description]
					}

					@sT = StripeTransaction.create(stripeCharge) # make a record in the StripeTransactions table
				end
			else
				stripeCharge = {
					txn_type: nil,
					currency: nil,
					total_amount: 0,
					notification_params: nil,
					txn_id: nil,
					status: nil,
					description: "$#{balance_used} was taken from your balance. No Stripe charges were necessary."
				}

				@sT = StripeTransaction.create(stripeCharge) # make a record in the StripeTransactions table
			end

			hash = {"transaction" => transaction, "seller" => seller, "item" => item}
			return hash
		end
		
		#if transaction exists redirect
		def transaction_exists?
			@item = Item.find(params[:item_id])
			@item_validate = @item.user_id == current_user.id

			@transaction_validate = Transaction.where("((transactions.buyer_id = #{current_user.id}) \
			AND transactions.item_id = #{params[:item_id]} AND \
			(transactions.status = 'Pending' OR transactions.status = 'Accepted' OR \
			 transactions.status = 'In Progress'))").empty?

			if !@transaction_validate || @item_validate
				redirect_to conversations_path
			end
		end

		#this will bounce users trying to purchase after lease.
		def transaction_owner?
			transaction = Transaction.find(params[:transaction])

			unless transaction.seller_id == current_user.id
				redirect_to items_path, flash: {alert: "You do not have access to this command."}
			end
		end

		def transaction_params
		  params.require(:transaction).permit(:item_id, :buyer_id, :seller_id, :length, :status, :total_price)
		end

		def signed_in_user
	  	unless signed_in?
	      redirect_to :back, flash: {warning: "Please sign in before you checkout."}
	  	end
	  end

end
