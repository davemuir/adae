module Api::V1
  class TransactionsController < BaseController

    before_action :authenticate_user_token!, only: [:verify_scan]

    def index
      transaction = Transaction.all
      if item_id = params[:item_id]
        transaction = Transaction.where(item_id: item_id)
      end

      render json: transaction, status: :ok
    end

    def show
      transaction = Transaction.where("transactions.seller_id = #{params[:id]} OR transactions.buyer_id = #{params[:id]}")

      if !transaction.nil?
        item = []
        user = []

        transaction.each do |t|

          item.push(Item.where(id: t.item_id).first)

          if t.buyer_id != params[:id].to_i
            user.push(User.where(id: t.buyer_id).first)
          else
            user.push(User.where(id: t.seller_id).first)
          end
        end

        render :json => {:transaction => transaction, :item => item, :user => user}
      else
        render json: {
          error: "No such transaction; check the user_id",
          status: 400
        }, status: 400
      end
    end

    def create
      transaction = Transaction.new(transaction_params)

      if transaction.save
        render nothing: true, status: 204#, location: user
      else
        render json: transaction.errors, status: 422
      end
    end

    def destroy
      transaction = Transaction.find(params[:id])

      if !transaction.nil?
        Transaction.destroy(params[:id])
        head :no_content
      else
        render json: {
          error: "No such transaction; check the transaction id",
          status: 400
        }, status: 400
      end
    end

    # Verifying a requested In scan or Out scan and updating the respective
    # users balance
    def verify_scan

      decoded = ""

      if !params[:transactions].nil? && !params[:transactions][:inscan].nil? && !params[:transactions][:balance].nil?
        decoded = decode(params[:transactions][:inscan].split(''))

        decoded = decoded.split('-')
        current_transaction = Transaction.where(id: decoded[0]).first
        seller = User.where(id: current_transaction[:seller_id]).first

        if !current_transaction.nil?
          transaction_validation = (current_transaction[:seller_id] == decoded[2].to_i) && (current_transaction[:buyer_id] == current_user[:id])

          if transaction_validation

            current_transaction.in_scan_date = DateTime.current
            current_transaction.save

            seller.total_price = seller.total_price + params[:transactions][:balance].to_i
            seller.save

            render nothing: true, status: 204
          else
            render json: {
              error: "Sorry incorrect QR Code detected.",
              status: 400
            }, status: 400
          end
        else
          render json: {
            error: "Transaction does not exist.",
            status: 400
          }, status: 400
        end

      elsif !params[:transactions] && !params[:transactions][:outscan].nil? && !params[:transactions][:balance].nil?
        decoded = decode(params[:transactions][:outscan].split(''))

        decoded = decoded.split('-')
        current_transaction = Transaction.where(id: decoded[0]).first

        if !current_transaction.nil?
          transaction_validation = (current_transaction[:seller_id] == decoded[2].to_i) && (current_transaction[:buyer_id] == current_user[:id])

          if transaction_validation

            current_transaction.out_scan_date = DateTime.current
            current_transaction.save

            render nothing: true, status: 204
          else
            render json: {
              error: "Sorry incorrect QR Code detected.",
              status: 400
            }, status: 400
          end
        else
          render json: {
            error: "Transaction does not exist.",
            status: 400
          }, status: 400
        end

      else
        render json: {
          error: "Sorry, invalid QR code.",
          status: 400
        }, status: 400
      end
    end

    private

      def transaction_params
        params.require(:transactions).permit(:start_date, :end_date,
        :return_date, :item_id, :buyer_id, :out_scan, :in_scan, :balance)
      end

      def decode(scrambled)

        encoder = ["a", "b", "c", "d", "e", "f", "g", "h",
        "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u",
        "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9"]

        encoded_JSON = ""

        scrambled.each do |char|
            if char !=  "-"
                position = encoder.index(char) - 8

                if position < 0
                    position = position + 36
                end

                encoded_JSON = encoded_JSON + encoder[position]
            else
                encoded_JSON = encoded_JSON + char
            end
        end

        return encoded_JSON
      end
  end
end
