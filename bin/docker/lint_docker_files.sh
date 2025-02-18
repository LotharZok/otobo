#!/usr/bin/env bash

# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

# Lint the dockerfiles with hadolint, https://github.com/hadolint/hadolint

for dockerfile in otobo.web.dockerfile otobo.nginx.dockerfile otobo.elasticsearch.dockerfile
do
	echo "Linting $dockerfile"
    docker run --rm -i hadolint/hadolint < $dockerfile
done
