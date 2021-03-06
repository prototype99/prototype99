# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

PYTHON_COMPAT=( python2_7 python3_{4,5,6} pypy )

inherit distutils-r1

DESCRIPTION="File transport adapter for Requests"
HOMEPAGE="https://github.com/dashea/requests-file"
SRC_URI="mirror://pypi/${PN:0:1}/${PN}/${P}.tar.gz"
RESTRICT="mirror"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"

DEPEND="dev-python/setuptools[${PYTHON_USEDEP}]"
RDEPEND="dev-python/six[${PYTHON_USEDEP}]
	>=dev-python/requests-1.0.0[${PYTHON_USEDEP}]"

#python_test() {
#	esetup.py test
#}
