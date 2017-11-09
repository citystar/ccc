require 'my_bitflyer'

module MyBitflyer
  class Currency
    def public_client
      @public_client ||= Bitflyer.http_public_client
    end

    def private_client
      @private_client ||= Bitflyer.http_private_client(conf[:api][:key], conf[:api][:secret])
    end

    def product_code
      "#{currency_code}_JPY"
    end

    def reload
      instance_variables.each do |var|
        remove_instance_variable(var)
      end
    end

    def balance
      @balacne ||= balance_info.select { |b| b['currency_code'] == currency_code }.first['available']
    end

    def jpy_balance
      @jpy_balacne ||= balance_info.select { |b| b['currency_code'] == 'JPY' }.first['available']
    end

    def price
      board['mid_price']
    end

    def price_for_selling
      price * (1 - commission_rate)
    end

    def price_for_buying
      price * (1 + commission_rate)
    end

    def sellable_size
      balance
    end

    def buyable_size
      jpy_balance / price_for_buying
    end

    def latest_sold_price
      return 0 if last_sell_order.nil?
      last_sell_order['price'].to_i * (1 - commission_rate)
    end

    def latest_bought_price
      jpy_for_buy_orders / sum_coin_of_buy_orders
    end

    def latest_bought_max_price
      buy_orders_after_last_sell.map do |b|
        b['price']
      end.max.to_i
    end

    def last_sell_order
      sell_orders.first
    end

    def last_buy_order
      buy_orders.first
    end

    def jpy_for_buy_orders
      buy_orders_after_last_sell.inject(0) do |sum, order|
        sum += order['price'] * order['size']
      end
    end

    def sum_coin_of_buy_orders
      buy_orders_after_last_sell.inject(0) do |sum, order|
        sum += order['size'] * (1 + commission_rate)
      end
    end

    def jpy_for_my_coin
      price * balance * (1 - commission_rate)
    end

    def buy_orders_after_last_sell
      @buy_orders_after_last_sell ||= buy_orders.select do |buy_order|
        last_sell_order.nil? || (buy_order['child_order_date'] > last_sell_order['child_order_date'])
      end
    end

    def buy_orders
      @buy_orders ||= child_orders.select { |co| co['side'] == 'BUY' }
    end

    def sell_orders
      @sell_orders ||= child_orders.select { |co| co['side'] == 'SELL' }
    end

    def last_action_buying?
      child_orders.first['side'] == 'BUY'
    end

    def asks
      board['asks']
    end

    def bids
      board['bids']
    end

    def available_asks
      board['asks'].select do |a|
        price_jpy = a['size'] < (balance * (1 - trading_commission))
      end
    end

    def available_bids
      board['bids'].select do |b|
        price_jpy = b['size'] * b['price']
        spend_jpy = price_jpy * (1 + commission_rate)
        spend_jpy < jpy_balance
      end
    end

    def commission_rate
      @commission_rate ||= private_client.trading_commission['commission_rate']
    end

    def buy(data)
      private_client.send_child_order(
        product_code,
        'LIMIT',
        'BUY',
        data[:price],
        data[:size]
      )
    end

    def sell(data)
      private_client.send_child_order(
        product_code,
        'LIMIT',
        'SELL',
        data[:price],
        data[:size]
      )
    end

    private

    def balance_info(reload: false)
      @balance_info =
        if reload
          private_client.balance
        else
          @balance_info || private_client.balance
        end
    end

    def board(reload: false)
      @board =
        if reload
          public_client.board(product_code)
        else
          @board || public_client.board(product_code)
        end
    end

    def child_orders(reload: false)
      @child_orders =
        if reload
          private_client.child_orders(product_code: product_code)
        else
          @child_orders || private_client.child_orders(product_code: product_code)
        end
    end

    def conf
      @conf ||= {api: {key: ENV['BITFLYER_API_KEY'], secret: ENV['BITFLYER_API_SECRET']}}
    end
  end
end
