class VpncJuniper < Formula
  desc "Cisco VPN concentrator client"
  homepage "https://www.unix-ag.uni-kl.de/~massar/vpnc/"
  url "https://github.com/ndpgroup/vpnc/archive/b1243d29e0c00312ead038b04a2cf5e2fa31d740.zip"
  mirror "https://github.com/ndpgroup/vpnc/archive/b1243d29e0c00312ead038b04a2cf5e2fa31d740.zip"
  version "0.5.4"
  sha256 "ed8e4179fd60d8ec84cf207f91a6d69d22565734e40d9063135296985e155427"

  option "with-hybrid", "Use vpnc hybrid authentication"

  deprecated_option "hybrid" => "with-hybrid"

  depends_on "pkg-config" => :build
  depends_on "libgcrypt"
  depends_on "libgpg-error"
  depends_on "gnutls"
  depends_on :tuntap
  depends_on "openssl" if build.with? "hybrid"

  fails_with :llvm do
    build 2334
  end

  # Patch from user @Imagesafari to enable compilation on Lion
  patch :DATA if MacOS.version >= :lion

  def install
    ENV.no_optimization
    ENV.deparallelize

    (var/"run/vpnc").mkpath

    inreplace ["vpnc-script", "vpnc-disconnect"] do |s|
      s.gsub! "/var/run/vpnc", "#{var}/run/vpnc"
    end

    inreplace "vpnc.8.template" do |s|
      s.gsub! "/etc/vpnc", "#{etc}/vpnc"
    end

    inreplace "Makefile" do |s|
      s.change_make_var! "PREFIX", prefix
      s.change_make_var! "ETCDIR", etc/"vpnc"

      s.gsub! /^#OPENSSL/, "OPENSSL" if build.with? "hybrid"
    end

    inreplace "config.c" do |s|
      s.gsub! "/etc/vpnc", "#{etc}/vpnc"
      s.gsub! "/var/run/vpnc", "#{var}/run/vpnc"
    end

    system "make"
    system "make", "install"
  end

  test do
    assert_match /vpnc version/, shell_output("#{sbin}/vpnc --version")
  end
end

__END__
--- vpnc/sysdep.h	2008-11-19 15:36:12.000000000 -0500
+++ vpnc.patched/sysdep.h	2011-07-14 12:49:18.000000000 -0400
@@ -109,6 +109,8 @@
 #define HAVE_FGETLN    1
 #define HAVE_UNSETENV  1
 #define HAVE_SETENV    1
+#define HAVE_GETLINE   1
+#define NEW_TUN        1
 #endif
 
 /***************************************************************************/
diff -u vpnc.patched/vpnc-script vpnc/vpnc-script
--- vpnc.patched/vpnc-script	2013-11-01 13:17:21.000000000 -0700
+++ vpnc/vpnc-script	2013-11-01 18:54:33.000000000 -0700
@@ -388,7 +388,7 @@
				scutil >/dev/null 2>&1 <<-EOF
					open
					d.init
-					d.add ServerAddresses * $INTERNAL_IP4_DNS
+					d.add ServerAddresses * $INTERNAL_IP4_DNS $INTERNAL_IP6_DNS
					set State:/Network/Service/$TUNDEV/DNS
					d.init
					# next line overrides the default gateway and breaks split routing
@@ -598,7 +598,7 @@
			fi
			i=`expr $i + 1`
		done
-		for i in $INTERNAL_IP4_DNS ; do
+		for i in $INTERNAL_IP6_DNS ; do
			if echo "$i" | grep : >/dev/null; then
				set_ipv6_network_route "$i" "128"
			fi
