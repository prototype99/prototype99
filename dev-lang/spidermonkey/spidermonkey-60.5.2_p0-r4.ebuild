# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6
WANT_AUTOCONF="2.1"
inherit autotools check-reqs toolchain-funcs pax-utils mozcoreconf-v5

MY_PN="mozjs"
MY_P="${MY_PN}-${PV/_rc/.rc}"
MY_P="${MY_P/_pre/pre}"
MY_P="${MY_P%_p[0-9]*}"
DESCRIPTION="Stand-alone JavaScript C++ library"
HOMEPAGE="https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey"
#SRC_URI="https://archive.mozilla.org/pub/spidermonkey/prereleases/60/pre3/${MY_P}.tar.bz2
SRC_URI="https://dev.gentoo.org/~axs/distfiles/${MY_P}.tar.bz2
	https://dev.gentoo.org/~anarchy/mozilla/patchsets/${PN}-60.0-patches-04.tar.xz"

LICENSE="NPL-1.1"
SLOT="60"
KEYWORDS="~alpha amd64 arm arm64 hppa ~ia64 ~mips ppc ppc64 ~s390 sparc x86"
IUSE="debug +jit minimal +system-icu test"

RESTRICT="!test? ( test ) ia64? ( test )"

S="${WORKDIR}/${MY_P%.rc*}"

BUILDDIR="${S}/jsobj"

RDEPEND=">=dev-libs/nspr-4.13.1
	virtual/libffi
	sys-libs/readline:0=
	>=sys-libs/zlib-1.2.3:=
	system-icu? ( >=dev-libs/icu-59.1:= )"
DEPEND="${RDEPEND}"

pkg_pretend() {
	CHECKREQS_DISK_BUILD="2G"

	check-reqs_pkg_setup
}
pkg_setup() {
	[[ ${MERGE_TYPE} == "binary" ]] || \
		moz_pkgsetup
	export SHELL="${EPREFIX}/bin/bash"
}

src_prepare() {
	eapply "${WORKDIR}/${PN}"/0003-build-Include-configure-script-be-nicer-about-option.patch
	eapply "${WORKDIR}/${PN}"/0005-CFLAGS-must-contain-fPIC-when-checking-the-linker.patch
	eapply "${WORKDIR}/${PN}"/0006-Ensure-we-fortify-properly-features.h-is-pulled-in-v.patch
	eapply "${FILESDIR}"/icu61.patch
	[[ ${CHOST} == *-darwin* ]] && eapply "${WORKDIR}/${PN}"/0002-build-Fix-library-install-name-on-macOS.patch
	[[ ${CHOST} == *-hurd* ]] && eapply "${WORKDIR}/${PN}"/hurd.patch
	[[ $(tc-endian) == "big" ]] && eapply "${WORKDIR}/${PN}"/0001-Bug-1488552-Ensure-proper-running-on-64-bit-and-32-b.patch
	tc-is-clang && eapply "${FILESDIR}/${PN}-60.5.2-clang.patch"
	if use alpha || use sparc; then
		eapply "${FILESDIR}"/deb-905825.patch
	fi
	local armel="use arm && tc-detect-is-softfloat"
	if ${armel} || use mips || use ppc || use ppc64 || use s390 || use sparc; then
		eapply "${FILESDIR}"/deb-878284.patch
		${armel} && eapply "${FILESDIR}"/deb-908481.patch
		if use mips; then
			eapply "${FILESDIR}"/moz-1444303.patch
			eapply "${FILESDIR}"/moz-1444834.patch
		fi
		if use ppc64 || use s390 || use sparc; then
			eapply "${FILESDIR}"/moz-1543659.patch
			use s390 && eapply "${FILESDIR}"/s390.patch
		fi
	fi
	if use arm64 && use jit; then
		eapply "${FILESDIR}"/moz-1375074.patch
		eapply "${FILESDIR}"/moz-1445907.patch
	fi
	use debug && eapply "${WORKDIR}/${PN}"/0004-We-must-drop-build-id-as-it-causes-conflicts-when-me.patch
	! use elibc_glibc && eapply "${WORKDIR}/${PN}"/0007-set-pthread-name-for-non-glibc-systems.patch
	use x86 && eapply "${FILESDIR}"/deb-907363.patch
	if use ia64; then
		eapply "${FILESDIR}/${PN}-60.5.2-ia64-support.patch"
		eapply "${FILESDIR}/${PN}-60.5.2-ia64-fix-virtual-address-length.patch"
		eapply "${FILESDIR}"/deb-897178.patch
	fi
	use system-icu && "${FILESDIR}"/system-icu.patch

	eapply_user

	if [[ ${CHOST} == *-freebsd* ]]; then
		# Don't try to be smart, this does not work in cross-compile anyway
		ln -sfn "${BUILDDIR}/config/Linux_All.mk" "${S}/config/$(uname -s)$(uname -r).mk" || die
	fi

	cd "${S}/js/src" || die
	eautoconf old-configure.in
	eautoconf

	# remove options that are not correct from js-config
	sed '/lib-filenames/d' -i "${S}"/js/src/build/js-config.in || die "failed to remove invalid option from js-config"

	# there is a default config.cache that messes everything up
	rm -f "${S}/js/src"/config.cache || die

	mkdir -p "${BUILDDIR}" || die
}

src_configure() {
	cd "${BUILDDIR}" || die

	ECONF_SOURCE="${S}/js/src" \
	econf \
		--disable-jemalloc \
		--enable-readline \
		--with-system-nspr \
		--with-system-zlib \
		--disable-optimize \
		--with-intl-api \
		$(use_with system-icu) \
		$(use_enable debug) \
		$(use_enable jit ion) \
		$(use_enable test tests) \
		XARGS="/usr/bin/xargs" \
		CONFIG_SHELL="${EPREFIX}/bin/bash" \
		CC="${CC}" CXX="${CXX}" LD="${LD}" AR="${AR}" RANLIB="${RANLIB}"
}

cross_make() {
	emake \
		CFLAGS="${BUILD_CFLAGS}" \
		CXXFLAGS="${BUILD_CXXFLAGS}" \
		AR="${BUILD_AR}" \
		CC="${BUILD_CC}" \
		CXX="${BUILD_CXX}" \
		RANLIB="${BUILD_RANLIB}" \
		"$@"
}
src_compile() {
	cd "${BUILDDIR}" || die
	if tc-is-cross-compiler; then
		tc-export_build_env BUILD_{AR,CC,CXX,RANLIB}
		cross_make \
			MOZ_OPTIMIZE_FLAGS="" MOZ_DEBUG_FLAGS="" \
			HOST_OPTIMIZE_FLAGS="" MODULE_OPTIMIZE_FLAGS="" \
			MOZ_PGO_OPTIMIZE_FLAGS="" \
			host_jsoplengen host_jskwgen
		cross_make \
			MOZ_OPTIMIZE_FLAGS="" MOZ_DEBUG_FLAGS="" HOST_OPTIMIZE_FLAGS="" \
			-C config nsinstall
		mv {,native-}host_jskwgen || die
		mv {,native-}host_jsoplengen || die
		mv config/{,native-}nsinstall || die
		sed -i \
			-e 's@./host_jskwgen@./native-host_jskwgen@' \
			-e 's@./host_jsoplengen@./native-host_jsoplengen@' \
			Makefile || die
		sed -i -e 's@/nsinstall@/native-nsinstall@' config/config.mk || die
		rm -f config/host_nsinstall.o \
			config/host_pathsub.o \
			host_jskwgen.o \
			host_jsoplengen.o || die
	fi

	MOZ_MAKE_FLAGS="${MAKEOPTS}" \
	emake \
		MOZ_OPTIMIZE_FLAGS="" MOZ_DEBUG_FLAGS="" \
		HOST_OPTIMIZE_FLAGS="" MODULE_OPTIMIZE_FLAGS="" \
		MOZ_PGO_OPTIMIZE_FLAGS=""
}

src_test() {
	cd "${BUILDDIR}/js/src/jsapi-tests" || die
	./jsapi-tests || die
}

src_install() {
	cd "${BUILDDIR}" || die
	emake DESTDIR="${D}" install

	if ! use minimal; then
		if use jit; then
			pax-mark m "${ED}"usr/bin/js${SLOT}
		fi
	else
		rm -f "${ED}"usr/bin/js${SLOT}
	fi

	# We can't actually disable building of static libraries
	# They're used by the tests and in a few other places
	find "${D}" -iname '*.a' -o -iname '*.ajs' -delete || die
}
