# The fake company store (Nimbus). A real, browsable site whose pages genuinely
# error / slow down when a fault is injected into a component. Every request is
# recorded as telemetry; Klaxon monitors this and the agent remediates it.
class StoreController < ApplicationController
  allow_unauthenticated_access
  layout "store"

  PRODUCTS = [
    { id: 1, name: "Nimbus Kablosuz Kulaklık", price: "1.299 ₺", emoji: "🎧" },
    { id: 2, name: "Nimbus Akıllı Saat",       price: "2.499 ₺", emoji: "⌚" },
    { id: 3, name: "Nimbus Bluetooth Hoparlör", price: "899 ₺",  emoji: "🔊" },
    { id: 4, name: "Nimbus Taşınabilir Şarj",  price: "449 ₺",   emoji: "🔋" },
    { id: 5, name: "Nimbus Mekanik Klavye",    price: "1.799 ₺", emoji: "⌨️" },
    { id: 6, name: "Nimbus 4K Webcam",         price: "1.149 ₺", emoji: "📷" }
  ].freeze

  def index
    result = StoreBackend.serve("magaza-vitrin", "/magaza")
    return render_store_error(result) unless result[:ok]
    @products = PRODUCTS
  end

  def product
    result = StoreBackend.serve("magaza-katalog", request.path)
    return render_store_error(result) unless result[:ok]
    @product = PRODUCTS.find { |p| p[:id] == params[:id].to_i } || PRODUCTS.first
  end

  def checkout
    result = StoreBackend.serve("magaza-odeme", "/magaza/odeme")
    return render_store_error(result) unless result[:ok]
    @reference = "NMB-#{rand(100_000..999_999)}"
  end

  # ---- demo control panel -------------------------------------------------

  def panel
    StoreBackend.ensure_components!
    @components = StoreBackend::COMPONENTS
    @faults = SiteFault.all.index_by(&:component)
    @stats  = @components.keys.index_with { |c| RequestLog.window_stats(c) }
    @faults_catalog = SiteFault::FIXES.keys
  end

  def inject
    StoreBackend.ensure_components!
    SiteFault.find_or_initialize_by(component: params[:component]).update!(fault: params[:fault])
    redirect_to store_panel_path,
      notice: "#{StoreBackend.component_name(params[:component])} → '#{params[:fault]}' arızası enjekte edildi."
  end

  def clear
    SiteFault.where(component: params[:component]).destroy_all
    redirect_to store_panel_path, notice: "Arıza temizlendi."
  end

  def traffic
    StoreTraffic.generate!(hits: 40)
    redirect_to store_panel_path, notice: "Trafik üretildi — telemetri güncellendi."
  end

  private

  def render_store_error(result)
    @status = result[:status]
    render :error, status: result[:status]
  end
end
