# Copyright 2017-2019 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit rindeal

## java-utils-2.eclass:
## java-pkg-2.eclass
EANT_GENTOO_CLASSPATH="
	commons-logging
	commons-compress
	commons-codec
	error-prone-annotations
	jmapviewer
	gettext-commons
	gettext-ant-tasks
	svgsalamander
	signpost
	ant-contrib
"
## java-ant-2.eclass:
JAVA_ANT_ENCODING=UTF-8

## EXPORT_FUNCTIONS: pkg_setup src_prepare src_compile pkg_preinst
inherit java-pkg-2
## EXPORT_FUNCTIONS: src_configure
inherit java-ant-2
## EXPORT_FUNCTIONS: src_prepare pkg_preinst pkg_postinst pkg_postrm
inherit xdg
## functions: make_desktop_entry, doicon, newicon
inherit desktop
## functions: ESVN_REPO_URI
inherit subversion

DESCRIPTION="Java-based editor for the OpenStreetMap project"
HOMEPAGE="https://josm.openstreetmap.de/"
LICENSE="GPL-2"
IUSE="noto"

SLOT="0"
ESVN_REPO_URI="https://josm.openstreetmap.de/svn/trunk@${PV}"

KEYWORDS="~amd64"
J="1.8"

CDEPEND_A=(
	"dev-java/commons-compress:0"
	"dev-java/commons-logging:0"
	"dev-java/error-prone-annotations:0"
	"dev-java/jmapviewer:0"
	"dev-java/gettext-commons:0"
	"dev-java/gettext-ant-tasks:0"
	"dev-java/svgsalamander:0"
	"dev-java/signpost:0"
)
DEPEND_A=( "${CDEPEND_A[@]}"
	">=virtual/jdk-${J}"
	"dev-java/javacc:0"
	"dev-java/ant-contrib:0"
	"app-text/xmlstarlet" # required for build files patching
	"dev-lang/perl"
	"dev-perl/TermReadKey"
)
RDEPEND_A=( "${CDEPEND_A[@]}"
	">=virtual/jre-${J}"
	"noto? ( media-fonts/noto )"
	"!noto? ( media-fonts/droid )"
)

RESTRICT+=" mirror"

inherit arrays

L10N_LOCALES=(
	af am ar ast az be bg bn br bs ca ca-ES cs cy da de de-DE el en-AU en-CA en-GB eo es et
	eu fa fi fil fo fr ga gl he hi hr ht hu hy ia id is it ja ka km ko ku ky lb lo lt lv mk mr ms
	nb nds nl nn oc pa pl pt pt-BR rm ro ru sk sl sq sr sv ta te th tr ug uk ur vi wae zh-CN zh-TW
)
inherit l10n-r1

src_prepare-locales() {
	local l locales dir="i18n/po" pre="" post=".po"

	l10n_find_changes_in_dir "${dir}" "${pre}" "${post}"

	l10n_get_locales locales app off
	for l in ${locales} ; do
		rrm "${dir}/${pre}${l}${post}"
		rsed -e "/languages\.put.*\"${l}\"/d" \
			-i -- src/org/openstreetmap/josm/tools/{I18n,LanguageInfo}.java || die
	done
}

src_prepare() {
	eapply "${FILESDIR}"/03-default_look_and_feel.patch
	eapply "${FILESDIR}"/04-use_system_jmapviewer.patch
	eapply "${FILESDIR}"/09-no-java-8.patch
	use noto && eapply "${FILESDIR}"/08-use_noto_font.patch
	use noto && eapply "${FILESDIR}"/07-use_system_fonts.patch

	xdg_src_prepare

	src_prepare-locales

	## print stats for EPSG compilation
	rsed -e "s|printStats *= *false|printStats = true|" \
		-i -- scripts/BuildProjectionDefinitions.java || die
	if use noto ; then
	## fix font path
	rsed -e 's,/usr/share/fonts/truetype/noto,/usr/share/fonts/noto,g' \
		-i -- src/org/openstreetmap/josm/tools/FontsManager.java || die
	fi

	## change default look and feel to GTK
	rsed -e 's|"javax.swing.plaf.metal.MetalLookAndFeel"|"com.sun.java.swing.plaf.gtk.GTKLookAndFeel"|' \
		-i -- src/org/openstreetmap/josm/tools/PlatformHookUnixoid.java || die

	## normalize user-agent
	rsed -r -e 's|(String *result *= *"JOSM/1.5 \(").*|\1 + v + ")";|' \
		-i -- src/org/openstreetmap/josm/data/Version.java || die
	rsed -e '/Main.platform.getOSDescription/d' -i -- src/org/openstreetmap/josm/data/Version.java || die
	rsed -r -e 's|(getAgentString\(\)) *\+.*|\1;|' -i -- src/org/openstreetmap/josm/data/Version.java || die

	## do not display MOTD by default, as it requires calling home
	rsed -e 's|getBoolean("help.displaymotd", true)|getBoolean("help.displaymotd", false)|' \
		-i -- src/org/openstreetmap/josm/gui/GettingStarted.java || die

	# update `REVISION` entry
	xmlstarlet ed --inplace -u "project/target[@name='create-revision']/echo[@file='\${revision.dir}/REVISION']" \
		-v "$(cat <<-_EOF_
			# automatically generated by JOSM build.xml - do not edit
			Revision: \${version.entry.commit.revision}
			Is-Local-Build: true
			Build-Date: \${build.tstamp}
			Build-Name: prototype99-ebuild
			Ebuild-Version: ${PVR}
			_EOF_
		)" build.xml || die

	java-pkg-2_src_prepare

	java-ant_rewrite-classpath
	java-ant_rewrite-classpath i18n/build.xml
}

src_compile() {
	EANT_GENTOO_CLASSPATH_EXTRA="${S}/src"
	# `dist-optimized` requires non-free obfuscator
	EANT_BUILD_TARGET="dist"
	# removes dependency on OpenJFX/Oracle JFX, but audio player will cease to work
	EANT_EXTRA_ARGS="-DnoJavaFX=true"

	java-pkg-2_src_compile
}

src_install() {
	### Main
	java-pkg_newjar "dist/${PN}-custom.jar" "${PN}.jar"

	java-pkg_dolauncher "${PN}" --jar "${PN}.jar" --java_args "-Dawt.useSystemAAFontSettings=lcd"

	### Data
	insinto /usr/share/${PN}
	doins -r images styles data

	### Icons
	doicon -s scalable "linux/tested/usr/share/icons/hicolor/scalable/apps/${PN}.svg"
	local s
	# unsupported sizes: 8 40 42 80
	for s in 16 22 24 32 36 48 64 72 96 128 192 256 512 ; do
		doicon -s ${s} "linux/tested/usr/share/icons/hicolor/${s}x${s}/apps/${PN}.png"
	done

	### Docs
	doman "linux/tested/usr/share/man/man1/${PN}.1"
	einstalldocs

	### Misc
	insinto /usr/share/appdata
	doins "linux/tested/usr/share/metainfo/${PN}.appdata.xml"

	local make_desktop_entry_args=(
		"${EPREFIX}/usr/bin/${PN} %F"	# exec
		"${PN^^}"	# name
		"${PN}"	# icon
		"Education;Science;Geoscience;Maps" # categories; https://standards.freedesktop.org/menu-spec/latest/apa.html
	)
	local make_desktop_entry_extras=(
		"StartupWMClass=org-openstreetmap-josm-Main"
		"MimeType=application/x-osm+xml;application/x-gpx+xml;x-scheme-handler/geo;"
		"GenericName=Java OpenStreetMap Editor"
	)
	make_desktop_entry "${make_desktop_entry_args[@]}" \
		"$( printf '%s\n' "${make_desktop_entry_extras[@]}" )"
}
