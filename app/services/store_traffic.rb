# Fires synthetic requests at every store component so there is a window of
# real telemetry for the monitor to read (faulted components produce errors /
# slowness, healthy ones produce clean 200s).
module StoreTraffic
  module_function

  PATHS = {
    "magaza-vitrin"  => "/magaza",
    "magaza-katalog" => "/magaza/urun/1",
    "magaza-odeme"   => "/magaza/odeme",
    "magaza-db"      => "/magaza/db"
  }.freeze

  def generate!(hits: 40)
    StoreBackend::COMPONENTS.each_key do |component|
      hits.times { StoreBackend.serve(component, PATHS.fetch(component, "/magaza")) }
    end
  end
end
