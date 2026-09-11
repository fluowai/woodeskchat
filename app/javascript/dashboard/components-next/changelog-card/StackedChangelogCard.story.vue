<script setup>
import StackedChangelogCard from './StackedChangelogCard.vue';

const imageCards = {
  id: 'woodesk-captain',
  title: 'Woodesk Captain',
  meta_title: 'Woodesk Captain',
  meta_description:
    'Watch how our latest feature can transform your workflow with powerful automation tools.',
  slug: 'woodesk-captain',
  feature_image:
    'https://www.woodesk.com/images/captain/captain_thumbnail.jpg',
};

const handleReadMore = () => {
  console.log(`Read more: ${imageCards.title}`);
};

const handleDismiss = () => {
  console.log(`Dismissed: ${imageCards.title}`);
};

const handleImgClick = () => {
  console.log(`Card clicked: ${imageCards.title}`);
};
</script>

<template>
  <Story
    title="Components/ChangelogCard/StackedChangelogCard"
    :layout="{ type: 'grid', width: '260px' }"
  >
    <Variant title="Single Card - With Image">
      <div class="p-3 bg-n-solid-2 w-56">
        <StackedChangelogCard
          :card="imageCards"
          is-active
          :is-dismissing="false"
          @read-more="handleReadMore(imageCards)"
          @dismiss="handleDismiss(imageCards)"
          @img-click="handleImgClick(imageCards)"
        />
      </div>
    </Variant>
  </Story>
</template>
