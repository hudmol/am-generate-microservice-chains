require 'securerandom'

HEADER = <<EOF
# -*- coding: utf-8 -*-
"""
Add a new mode selection prior to generating thumbnails.  The user can
choose to generate thumbnails (the previous default), skip generating thumbnails
entirely, or to only generate thumbnails if there is an active FPRule for the
given file type.
"""
from __future__ import unicode_literals

from django.db import migrations
from dateutil.parser import parse as parse_date
from django.db.models.functions import Concat
from django.db.models import Value, Func, F
EOF

TEMPLATE = <<EOF
TaskConfig.objects.create(
    pk='{{SET_RETURN_TASK_UUID}}',
    tasktypepkreference='{{SET_UNIT_VARIABLE_UUID}}',
    description='Set normalize path',
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    replaces=None,
    tasktype_id='6f0b612c-867f-4dfd-8e43-5b35b7f882d7'
)

TaskConfigSetUnitVariable.objects.create(
    pk='{{SET_UNIT_VARIABLE_UUID}}',
    updatedtime=None,
    microservicechainlink_id='{{TARGET_CHAINLINK_UUID}}',
    createdtime=parse_date('2018-06-28T00:00:00+00:00'),
    variablevalue=None,
    variable='normalizationThumbnailProcessing',
)

MicroServiceChainLink.objects.create(
    pk='{{GATEKEEPER_CHAINLINK_UUID}}',
    microservicegroup='Normalize',
    reloadfilelist=1,
    defaultexitmessage=2,
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    currenttask_id='{{SET_RETURN_TASK_UUID}}',
    defaultnextchainlink=None,
    replaces=None
)

MicroServiceChainLinkExitCode.objects.create(
    pk='{{EXITCODE_UUID}}',
    exitcode=0,
    exitmessage=2,
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    microservicechainlink_id='{{GATEKEEPER_CHAINLINK_UUID}}',
    nextmicroservicechainlink_id='{{GET_THUMBNAIL_MODE_LINK_UUID}}',
    replaces=None)

MicroServiceChainLink.objects \\
    .filter(pk='{{SOURCE_CHAINLINK_UUID}}') \\
    .update(defaultnextchainlink_id='{{GATEKEEPER_CHAINLINK_UUID}}')

MicroServiceChainLinkExitCode.objects \\
    .filter(microservicechainlink_id='{{SOURCE_CHAINLINK_UUID}}') \\
    .update(nextmicroservicechainlink_id='{{GATEKEEPER_CHAINLINK_UUID}}')
EOF

TEMPLATE_GLOBAL = <<EOF
# Return home once the selection has been made
TaskConfig.objects.create(
    pk='{{RETURN_HOME_TASK_UUID}}',
    tasktypepkreference='{{RETURN_HOME_LINK_PULL_UUID}}',
    description='Return to normalization step',
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    replaces=None,
    tasktype_id='c42184a3-1a7f-4c4d-b380-15d8d97fdd11'
)

TaskConfigUnitVariableLinkPull.objects.create(
    pk='{{RETURN_HOME_LINK_PULL_UUID}}',
    variable='normalizationThumbnailProcessing',
    variablevalue=None,
    createdtime=parse_date('2018-06-28T00:00:00+00:00'),
    updatedtime=None,
    defaultmicroservicechainlink=None,
)

MicroServiceChainLink.objects.create(
    pk='{{RETURN_HOME_LINK_UUID}}',
    microservicegroup='Normalize',
    reloadfilelist=1,
    defaultexitmessage=2,
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    currenttask_id='{{RETURN_HOME_TASK_UUID}}',
    defaultnextchainlink=None,
    replaces=None)

TaskConfig.objects.create(
    pk='{{GET_THUMBNAIL_MODE_TASK_UUID}}',
    tasktypepkreference=None,
    description='Choose thumbnail mode',
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    replaces=None,
    tasktype_id='9c84b047-9a6d-463f-9836-eafa49743b84'
)

MicroServiceChainLink.objects.create(
    pk='{{GET_THUMBNAIL_MODE_LINK_UUID}}',
    microservicegroup='Normalize',
    reloadfilelist=1,
    defaultexitmessage=2,
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    currenttask_id='{{GET_THUMBNAIL_MODE_TASK_UUID}}',
    defaultnextchainlink=None,
    replaces=None)

MicroServiceChoiceReplacementDic.objects.create(
    pk='{{CHOICE_1_UUID}}',
    description='Yes',
    replacementdic='{"%ThumbnailMode%": "generate"}',
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    choiceavailableatlink_id='{{GET_THUMBNAIL_MODE_LINK_UUID}}',
    replaces=None)

MicroServiceChoiceReplacementDic.objects.create(
    pk='{{CHOICE_3_UUID}}',
    description='Yes, without default',
    replacementdic='{"%ThumbnailMode%": "generate_non_default"}',
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    choiceavailableatlink_id='{{GET_THUMBNAIL_MODE_LINK_UUID}}',
    replaces=None)

MicroServiceChoiceReplacementDic.objects.create(
    pk='{{CHOICE_2_UUID}}',
    description='No',
    replacementdic='{"%ThumbnailMode%": "do_not_generate"}',
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    choiceavailableatlink_id='{{GET_THUMBNAIL_MODE_LINK_UUID}}',
    replaces=None)

MicroServiceChainLinkExitCode.objects.create(
    pk='{{SELECTION_MADE_EXITCODE_UUID}}',
    exitcode=0,
    exitmessage=2,
    lastmodified=parse_date('2018-06-28T00:00:00+00:00'),
    microservicechainlink_id='{{GET_THUMBNAIL_MODE_LINK_UUID}}',
    nextmicroservicechainlink_id='{{RETURN_HOME_LINK_UUID}}',
    replaces=None)

StandardTaskConfig.objects \\
    .filter(execute='normalize_v1.0', arguments__startswith='thumbnail') \\
    .update(arguments=Concat('arguments', Value(' --thumbnail_mode "%ThumbnailMode%"')))

# Update 'Remove bagged files' to use new removeDirectories_v0.0 script
StandardTaskConfig.objects \\
    .filter(pk='d12b6b59-1f1c-47c2-b1a3-2bf898740eae') \\
    .update(
        execute='removeDirectories_v0.0',
        arguments='"%SIPDirectory%%SIPName%-%SIPUUID%" "%SIPLogsDirectory%" "%SIPObjectsDirectory%" "%SIPDirectory%thumbnails/"')

# Update 'Copy thumbnails to DIP directory' to use new copyThumbnailsToDIPDirectory_v0.0 script
StandardTaskConfig.objects \\
    .filter(pk='6abefa8d-387d-4f23-9978-bea7e6657a57') \\
    .update(
        execute='copyThumbnailsToDIPDirectory_v0.0',
        arguments='\\"%SIPDirectory%thumbnails\\" \\"%SIPDirectory%DIP\\"')
EOF




TEMPLATE_DOWN = <<EOF
MicroServiceChainLinkExitCode.objects \\
    .filter(microservicechainlink_id='{{SOURCE_CHAINLINK_UUID}}') \\
    .update(nextmicroservicechainlink_id='{{TARGET_CHAINLINK_UUID}}')

MicroServiceChainLink.objects \\
    .filter(pk='{{SOURCE_CHAINLINK_UUID}}') \\
    .update(defaultnextchainlink_id='{{TARGET_CHAINLINK_UUID}}')

MicroServiceChainLinkExitCode.objects.filter(pk='{{EXITCODE_UUID}}').delete()
MicroServiceChainLink.objects.filter(pk='{{GATEKEEPER_CHAINLINK_UUID}}').delete()
TaskConfigSetUnitVariable.objects.filter(pk='{{SET_UNIT_VARIABLE_UUID}}').delete()
TaskConfig.objects.filter(pk='{{SET_RETURN_TASK_UUID}}').delete()
EOF

TEMPLATE_GLOBAL_DOWN = <<EOF
StandardTaskConfig.objects \\
    .filter(execute='normalize_v1.0') \\
    .update(arguments=Func(F('arguments'), Value(' --thumbnail_mode "%ThumbnailMode%"'), Value(''), function='replace'))

MicroServiceChainLinkExitCode.objects.filter(pk='{{SELECTION_MADE_EXITCODE_UUID}}').delete()

MicroServiceChoiceReplacementDic.objects.filter(pk='{{CHOICE_2_UUID}}').delete()

MicroServiceChoiceReplacementDic.objects.filter(pk='{{CHOICE_3_UUID}}').delete()

MicroServiceChoiceReplacementDic.objects.filter(pk='{{CHOICE_1_UUID}}').delete()

MicroServiceChainLink.objects.filter(pk='{{GET_THUMBNAIL_MODE_LINK_UUID}}').delete()

TaskConfig.objects.filter(pk='{{GET_THUMBNAIL_MODE_TASK_UUID}}').delete()

MicroServiceChainLink.objects.filter(pk='{{RETURN_HOME_LINK_UUID}}').delete()

TaskConfigUnitVariableLinkPull.objects.filter(pk='{{RETURN_HOME_LINK_PULL_UUID}}').delete()

TaskConfig.objects.filter(pk='{{RETURN_HOME_TASK_UUID}}').delete()

StandardTaskConfig.objects \\
    .filter(pk='d12b6b59-1f1c-47c2-b1a3-2bf898740eae') \\
    .update(
        execute='remove_v0.0',
        arguments='-R "%SIPDirectory%%SIPName%-%SIPUUID%" "%SIPLogsDirectory%" "%SIPObjectsDirectory%" "%SIPDirectory%thumbnails/"')

StandardTaskConfig.objects \\
    .filter(pk='6abefa8d-387d-4f23-9978-bea7e6657a57') \\
    .update(
        execute='copy_v0.0',
        arguments='-R "%SIPDirectory%thumbnails" "%SIPDirectory%DIP/."')

EOF



#######################################################################


GET_THUMBNAIL_MODE_LINK_UUID = SecureRandom.uuid


def global(up, down)
    vars = {
        'CHOICE_1_UUID' => SecureRandom.uuid,
        'CHOICE_2_UUID' => SecureRandom.uuid,
        'CHOICE_3_UUID' => SecureRandom.uuid,
        'GET_THUMBNAIL_MODE_LINK_UUID' => GET_THUMBNAIL_MODE_LINK_UUID,
        'GET_THUMBNAIL_MODE_TASK_UUID' => SecureRandom.uuid,
        'RETURN_HOME_LINK_PULL_UUID' => SecureRandom.uuid,
        'RETURN_HOME_LINK_UUID' => SecureRandom.uuid,
        'RETURN_HOME_TASK_UUID' => SecureRandom.uuid,
        'SELECTION_MADE_EXITCODE_UUID' => SecureRandom.uuid,
    }

    up << vars.reduce(TEMPLATE_GLOBAL) do |s, (var, value)|
        s.gsub("{{#{var}}}", value)
    end.strip

    down << vars.reduce(TEMPLATE_GLOBAL_DOWN) do |s, (var, value)|
        s.gsub("{{#{var}}}", value)
    end.strip
end

def per_normalize_chain(source_uuid, dest_uuid, up, down)
    vars = {
        'EXITCODE_UUID' => SecureRandom.uuid,
        'GATEKEEPER_CHAINLINK_UUID' => SecureRandom.uuid,
        'GET_THUMBNAIL_MODE_TASK_UUID' => SecureRandom.uuid,
        'GET_THUMBNAIL_MODE_LINK_UUID' => GET_THUMBNAIL_MODE_LINK_UUID,
        'SET_RETURN_TASK_UUID' => SecureRandom.uuid,
        'SET_UNIT_VARIABLE_UUID' => SecureRandom.uuid,
        'SOURCE_CHAINLINK_UUID' => source_uuid,
        'TARGET_CHAINLINK_UUID' => dest_uuid,
    }

    up << vars.reduce(TEMPLATE) do |s, (var, value)|
        s.gsub("{{#{var}}}", value)
    end.strip

    down << vars.reduce(TEMPLATE_DOWN) do |s, (var, value)|
        s.gsub("{{#{var}}}", value)
    end.strip
end

CHAINS_TO_SEPARATE = [['4103a5b0-e473-4198-8ff7-aaa6fec34749', '092b47db-6f77-4072-aed3-eb248ab69e9c'],
                      ['35c8763a-0430-46be-8198-9ecb23f895c8', '180ae3d0-aa6c-4ed4-ab94-d0a2121e7f21'],
                      ['31abe664-745e-4fef-a669-ff41514e0083', '09b85517-e5f5-415b-a950-1a60ee285242'],
                      ['0b92a510-a290-44a8-86d8-6b7139be29df', 'f6fdd1a7-f0c5-4631-b5d3-19421155bd7a'],
                      ['56da7758-913a-4cd2-a815-be140ed09357', '8ce130d4-3f7e-46ec-868a-505cf9033d96'],
                      ['6b931965-d5f6-4611-a536-39d5901f8f70', '0a6558cf-cf5f-4646-977e-7d6b4fde47e8'],
                      ['f3a39155-d655-4336-8227-f8c88e4b7669', 'e950cd98-574b-4e57-9ef8-c2231e1ce451']]


def indent_block(s)
    s.split("\n").map {|s| "    #{s}"}.map(&:rstrip).join("\n")
end

def main
    up = []
    down = []

    global(up, down)

    CHAINS_TO_SEPARATE.each do |source, target|
        per_normalize_chain(source, target, up, down)
    end

    puts HEADER
    puts ""
    puts ""
    puts <<EOF
def data_migration_down(apps, schema_editor):
    """
    Remove thumbnail mode selection prior to the links that run normalize
    thumbnails.
    """
    MicroServiceChainLink = apps.get_model('main', 'MicroServiceChainLink')
    MicroServiceChainLinkExitCode = apps.get_model('main', 'MicroServiceChainLinkExitCode')
    MicroServiceChoiceReplacementDic = apps.get_model('main', 'MicroServiceChoiceReplacementDic')
    StandardTaskConfig = apps.get_model('main', 'StandardTaskConfig')
    TaskConfig = apps.get_model('main', 'TaskConfig')
    TaskConfigSetUnitVariable = apps.get_model('main', 'TaskConfigSetUnitVariable')
    TaskConfigUnitVariableLinkPull = apps.get_model('main', 'TaskConfigUnitVariableLinkPull')

EOF

    puts indent_block(down.join("\n\n"))

puts <<EOF


def data_migration_up(apps, schema_editor):
    """
    Add a normalize thumbnail mode selection prior to the links that run
    normalize thumbnails.
    """
    MicroServiceChainLink = apps.get_model('main', 'MicroServiceChainLink')
    MicroServiceChainLinkExitCode = apps.get_model('main', 'MicroServiceChainLinkExitCode')
    MicroServiceChoiceReplacementDic = apps.get_model('main', 'MicroServiceChoiceReplacementDic')
    StandardTaskConfig = apps.get_model('main', 'StandardTaskConfig')
    TaskConfig = apps.get_model('main', 'TaskConfig')
    TaskConfigSetUnitVariable = apps.get_model('main', 'TaskConfigSetUnitVariable')
    TaskConfigUnitVariableLinkPull = apps.get_model('main', 'TaskConfigUnitVariableLinkPull')

EOF

    puts indent_block(up.join("\n\n"))

    puts <<EOF


class Migration(migrations.Migration):
    """Entry point for the migration."""
    dependencies = [('main', '0052_correct_extract_packages_fallback_link')]
    operations = [
        migrations.RunPython(data_migration_up, data_migration_down),
    ]
EOF

end


main
