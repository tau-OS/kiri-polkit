project (
    # todo: rename to kiri-polkit-agent and move to /usr/libexec/kiri-polkit-agent
    'tau-polkit-agent',
    'vala', 'c',
    version : '0.1.0',
)

add_project_arguments([
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
        '-DG_LOG_DOMAIN="com.fyralabs.KiriPolkitAgent"'
    ],
    language: 'c'
)

gnome = import('gnome')

conf_data = configuration_data()
conf_data.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: conf_data
)
vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

pkg = import('pkgconfig')
glib_dep = dependency('glib-2.0', version: '>=2.72')
gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
gmodule_dep = dependency('gmodule-2.0')
gtk_dep = dependency('gtk4', version: '>=3.10')
helium_dep = dependency('libhelium-1')
bismuth_dep = dependency('libbismuth-1', fallback: [ 'libbismuth', 'libbismuth_dep' ], version: '>=1.0.0')
m_dep = meson.get_compiler('c').find_library('m', required : false)

subdir('src')
