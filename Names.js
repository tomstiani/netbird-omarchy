function shortHost(fqdn) {
  // NetBird peer DNS domains vary between cloud and self-hosted deployments.
  return String(fqdn || "").replace(/\.$/, "").split(".")[0]
}

function isProxy(peer) {
  return /^proxy-[a-z0-9]+-\d+-\d+$/i.test(shortHost(peer.fqdn))
}

function displayName(peer) {
  var host = shortHost(peer.fqdn || peer.name)
  if (!host) return "Unknown peer"
  if (isProxy(peer)) {
    var ip = String(peer.netbirdIp || "")
    var octets = ip.split(".")
    return "Proxy · " + (octets.length === 4 ? octets.slice(2).join(".") : host.slice(-12))
  }
  return host.split(/[-_]+/).map(function(word) {
    if (/^s\d+$/i.test(word)) return word.toUpperCase()
    if (/^macbook$/i.test(word)) return "MacBook"
    return word.charAt(0).toUpperCase() + word.slice(1)
  }).join(" ")
}

function sortedPeers(peers) {
  return (peers || []).slice().sort(function(a, b) {
    if (isProxy(a) !== isProxy(b)) return isProxy(a) ? 1 : -1
    return displayName(a).localeCompare(displayName(b), undefined, { numeric: true })
  })
}

if (typeof module !== "undefined") module.exports = { shortHost, isProxy, displayName, sortedPeers }
